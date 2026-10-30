//! Linux X11 sessions (any window manager that follows EWMH: GNOME on Xorg, KDE on X11, Xfce,
//! Cinnamon, MATE, i3…). Shortcuts come from XGrabKey on the root window; windows are read and
//! moved through the EWMH properties and messages; monitors come from RandR.

use std::sync::mpsc;
use std::sync::Mutex;
use std::time::Duration;

use split_core::shortcuts::KeyCombo;
use split_core::{Action, Move, Rect, Screen, Snapshot, WindowInfo};
use x11rb::connection::Connection;
use x11rb::protocol::randr::ConnectionExt as _;
use x11rb::protocol::xproto::{
    AtomEnum, ClientMessageEvent, ConnectionExt as _, EventMask, GrabMode, ModMask, Window,
};
use x11rb::protocol::Event;
use x11rb::rust_connection::RustConnection;

use super::{Backend, OnShortcut, Status};

x11rb::atom_manager! {
    Atoms: AtomsCookie {
        _NET_ACTIVE_WINDOW,
        _NET_CLIENT_LIST,
        _NET_CLIENT_LIST_STACKING,
        _NET_CURRENT_DESKTOP,
        _NET_WORKAREA,
        _NET_WM_DESKTOP,
        _NET_WM_PID,
        _NET_WM_STATE,
        _NET_WM_STATE_HIDDEN,
        _NET_WM_STATE_SKIP_TASKBAR,
        _NET_WM_STATE_MAXIMIZED_VERT,
        _NET_WM_STATE_MAXIMIZED_HORZ,
        _NET_WM_STATE_FULLSCREEN,
        _NET_WM_WINDOW_TYPE,
        _NET_WM_WINDOW_TYPE_NORMAL,
        _NET_WM_STRUT,
        _NET_WM_STRUT_PARTIAL,
        _NET_FRAME_EXTENTS,
        _GTK_FRAME_EXTENTS,
        _NET_MOVERESIZE_WINDOW,
        WM_CLASS,
    }
}

type Reply = mpsc::Sender<Vec<Action>>;

pub struct X11Backend {
    connection: RustConnection,
    root: Window,
    root_size: (f64, f64),
    atoms: Atoms,
    requests: Mutex<mpsc::Sender<(Vec<(Action, KeyCombo)>, Reply)>>,
}

fn error(e: impl std::fmt::Display) -> String {
    e.to_string()
}

impl X11Backend {
    pub fn start(on_shortcut: OnShortcut) -> Result<Self, String> {
        let (connection, screen_number) = x11rb::connect(None).map_err(error)?;
        let screen = &connection.setup().roots[screen_number];
        let root = screen.root;
        let root_size = (screen.width_in_pixels as f64, screen.height_in_pixels as f64);
        let atoms = Atoms::new(&connection).map_err(error)?.reply().map_err(error)?;
        let (request_tx, request_rx) = mpsc::channel();
        std::thread::Builder::new()
            .name("split-shortcuts".into())
            .spawn(move || {
                if let Err(e) = shortcut_thread(on_shortcut, request_rx) {
                    eprintln!("split: the X11 shortcut thread stopped: {e}");
                }
            })
            .map_err(error)?;
        Ok(Self { connection, root, root_size, atoms, requests: Mutex::new(request_tx) })
    }

    fn cardinals(&self, window: Window, property: u32) -> Vec<u32> {
        self.connection
            .get_property(false, window, property, AtomEnum::ANY, 0, 1024)
            .ok()
            .and_then(|c| c.reply().ok())
            .and_then(|r| r.value32().map(|v| v.collect()))
            .unwrap_or_default()
    }

    fn app_of(&self, window: Window) -> String {
        let bytes = self
            .connection
            .get_property(false, window, self.atoms.WM_CLASS, AtomEnum::STRING, 0, 256)
            .ok()
            .and_then(|c| c.reply().ok())
            .map(|r| r.value)
            .unwrap_or_default();
        // WM_CLASS is "instance\0class\0"; the class names the program.
        let parts: Vec<&[u8]> = bytes.split(|b| *b == 0).filter(|p| !p.is_empty()).collect();
        let class = parts.get(1).or(parts.first()).copied().unwrap_or_default();
        String::from_utf8_lossy(class).into_owned()
    }

    /// The window as people see it: the client area plus the window manager's frame, minus the
    /// invisible shadow GTK draws around client-side decorated windows.
    fn visible_rect(&self, window: Window) -> Option<Rect> {
        let geometry = self.connection.get_geometry(window).ok()?.reply().ok()?;
        let origin = self.connection.translate_coordinates(window, self.root, 0, 0).ok()?.reply().ok()?;
        let frame = self.extents(window, self.atoms._NET_FRAME_EXTENTS);
        let shadow = self.extents(window, self.atoms._GTK_FRAME_EXTENTS);
        Some(Rect::new(
            origin.dst_x as f64 - frame[0] + shadow[0],
            origin.dst_y as f64 - frame[2] + shadow[2],
            geometry.width as f64 + frame[0] + frame[1] - shadow[0] - shadow[1],
            geometry.height as f64 + frame[2] + frame[3] - shadow[2] - shadow[3],
        ))
    }

    /// left, right, top, bottom
    fn extents(&self, window: Window, property: u32) -> [f64; 4] {
        let values = self.cardinals(window, property);
        if values.len() >= 4 {
            [values[0] as f64, values[1] as f64, values[2] as f64, values[3] as f64]
        } else {
            [0.0; 4]
        }
    }

    fn info(&self, window: Window) -> Option<WindowInfo> {
        if window == 0 || window == self.root || self.is_own(window) {
            return None;
        }
        Some(WindowInfo { id: window as u64, rect: self.visible_rect(window)?, app: self.app_of(window) })
    }

    fn is_own(&self, window: Window) -> bool {
        self.cardinals(window, self.atoms._NET_WM_PID).first().copied() == Some(std::process::id())
    }

    fn current_desktop(&self) -> u32 {
        self.cardinals(self.root, self.atoms._NET_CURRENT_DESKTOP).first().copied().unwrap_or(0)
    }

    fn is_ordinary(&self, window: Window, desktop: u32) -> bool {
        let types = self.cardinals(window, self.atoms._NET_WM_WINDOW_TYPE);
        if !types.is_empty() && !types.contains(&self.atoms._NET_WM_WINDOW_TYPE_NORMAL) {
            return false;
        }
        let state = self.cardinals(window, self.atoms._NET_WM_STATE);
        if state.contains(&self.atoms._NET_WM_STATE_HIDDEN) || state.contains(&self.atoms._NET_WM_STATE_SKIP_TASKBAR) {
            return false;
        }
        match self.cardinals(window, self.atoms._NET_WM_DESKTOP).first() {
            Some(&d) => d == desktop || d == 0xFFFF_FFFF,
            None => true,
        }
    }

    fn screens(&self) -> Vec<Screen> {
        let mut screens: Vec<Screen> = self
            .connection
            .randr_get_monitors(self.root, true)
            .ok()
            .and_then(|c| c.reply().ok())
            .map(|r| {
                r.monitors
                    .iter()
                    .map(|m| {
                        let frame = Rect::new(m.x as f64, m.y as f64, m.width as f64, m.height as f64);
                        Screen { frame, work_area: frame, scale: 1.0, primary: m.primary }
                    })
                    .collect()
            })
            .unwrap_or_default();
        if screens.is_empty() {
            let frame = Rect::new(0.0, 0.0, self.root_size.0, self.root_size.1);
            screens.push(Screen { frame, work_area: frame, scale: 1.0, primary: true });
        }
        if !screens.iter().any(|s| s.primary) {
            screens[0].primary = true;
        }

        // _NET_WORKAREA is one rect for all monitors together. Use it where it fits a monitor
        // well; struts below take care of panels on single monitors.
        let workareas = self.cardinals(self.root, self.atoms._NET_WORKAREA);
        let index = self.current_desktop() as usize * 4;
        let workarea = workareas
            .get(index..index + 4)
            .or_else(|| workareas.get(0..4))
            .map(|v| Rect::new(v[0] as f64, v[1] as f64, v[2] as f64, v[3] as f64));
        for screen in &mut screens {
            if let Some(area) = workarea.and_then(|w| w.intersection(&screen.frame)) {
                if area.area() >= screen.frame.area() * 0.5 {
                    screen.work_area = area;
                }
            }
        }
        for strut in self.struts() {
            for screen in &mut screens {
                apply_strut(screen, &strut, self.root_size);
            }
        }
        screens
    }

    /// Panels and docks reserve screen edges with _NET_WM_STRUT_PARTIAL (or the older _NET_WM_STRUT).
    fn struts(&self) -> Vec<[f64; 12]> {
        let children = self
            .connection
            .query_tree(self.root)
            .ok()
            .and_then(|c| c.reply().ok())
            .map(|r| r.children)
            .unwrap_or_default();
        let mut windows = children;
        windows.extend(self.cardinals(self.root, self.atoms._NET_CLIENT_LIST));
        windows.sort_unstable();
        windows.dedup();
        let mut struts = Vec::new();
        for window in windows {
            let partial = self.cardinals(window, self.atoms._NET_WM_STRUT_PARTIAL);
            if partial.len() >= 12 {
                let mut s = [0.0; 12];
                for (i, v) in partial.iter().take(12).enumerate() {
                    s[i] = *v as f64;
                }
                struts.push(s);
                continue;
            }
            let simple = self.cardinals(window, self.atoms._NET_WM_STRUT);
            if simple.len() >= 4 {
                let (w, h) = self.root_size;
                struts.push([
                    simple[0] as f64, simple[1] as f64, simple[2] as f64, simple[3] as f64,
                    0.0, h, 0.0, h, 0.0, w, 0.0, w,
                ]);
            }
        }
        struts
    }

    fn send_to_root(&self, window: Window, message: u32, data: [u32; 5]) -> Result<(), String> {
        let event = ClientMessageEvent::new(32, window, message, data);
        self.connection
            .send_event(false, self.root, EventMask::SUBSTRUCTURE_REDIRECT | EventMask::SUBSTRUCTURE_NOTIFY, event)
            .map_err(error)?;
        Ok(())
    }
}

/// Takes a panel's reserved edge off a monitor's work area when the panel sits on that monitor.
fn apply_strut(screen: &mut Screen, s: &[f64; 12], (root_w, root_h): (f64, f64)) {
    let f = screen.frame;
    let mut w = screen.work_area;
    let overlaps = |a0: f64, a1: f64, b0: f64, b1: f64| a0 <= b1 && b0 <= a1;
    let [left, right, top, bottom, left_y0, left_y1, right_y0, right_y1, top_x0, top_x1, bottom_x0, bottom_x1] = *s;
    if left > 0.0 && f.x < left && overlaps(left_y0, left_y1, f.y, f.max_y()) {
        let max_x = w.max_x();
        w.x = w.x.max(left);
        w.width = max_x - w.x;
    }
    if right > 0.0 && f.max_x() > root_w - right && overlaps(right_y0, right_y1, f.y, f.max_y()) {
        w.width = w.max_x().min(root_w - right) - w.x;
    }
    if top > 0.0 && f.y < top && overlaps(top_x0, top_x1, f.x, f.max_x()) {
        let max_y = w.max_y();
        w.y = w.y.max(top);
        w.height = max_y - w.y;
    }
    if bottom > 0.0 && f.max_y() > root_h - bottom && overlaps(bottom_x0, bottom_x1, f.x, f.max_x()) {
        w.height = w.max_y().min(root_h - bottom) - w.y;
    }
    if !w.is_empty() {
        screen.work_area = w;
    }
}

impl Backend for X11Backend {
    fn snapshot(&self, with_windows: bool) -> Result<Snapshot, String> {
        let active = self.cardinals(self.root, self.atoms._NET_ACTIVE_WINDOW).first().copied().unwrap_or(0);
        let windows = if with_windows {
            let desktop = self.current_desktop();
            let mut stacking = self.cardinals(self.root, self.atoms._NET_CLIENT_LIST_STACKING);
            stacking.reverse(); // the property lists bottom to top
            stacking
                .into_iter()
                .filter(|w| self.is_ordinary(*w, desktop))
                .filter_map(|w| self.info(w))
                .collect()
        } else {
            Vec::new()
        };
        Ok(Snapshot { active: self.info(active), screens: self.screens(), windows })
    }

    fn apply(&self, moves: &[Move]) -> Result<(), String> {
        let a = &self.atoms;
        for item in moves {
            let window = item.id as Window;
            // A maximized or full screen window ignores new sizes, so those states go first.
            self.send_to_root(window, a._NET_WM_STATE, [0, a._NET_WM_STATE_MAXIMIZED_VERT, a._NET_WM_STATE_MAXIMIZED_HORZ, 2, 0])?;
            self.send_to_root(window, a._NET_WM_STATE, [0, a._NET_WM_STATE_FULLSCREEN, 0, 2, 0])?;
            let frame = self.extents(window, a._NET_FRAME_EXTENTS);
            let shadow = self.extents(window, a._GTK_FRAME_EXTENTS);
            let r = item.rect;
            // North-west gravity: x and y are where the outer frame starts, width and height are
            // the client size. The GTK shadow sits outside what people see, so it is added back.
            let x = r.x - shadow[0];
            let y = r.y - shadow[2];
            let width = (r.width - frame[0] - frame[1] + shadow[0] + shadow[1]).max(1.0);
            let height = (r.height - frame[2] - frame[3] + shadow[2] + shadow[3]).max(1.0);
            let flags = 1 | (1 << 8) | (1 << 9) | (1 << 10) | (1 << 11) | (2 << 12);
            self.send_to_root(
                window,
                a._NET_MOVERESIZE_WINDOW,
                [flags, x.round() as i32 as u32, y.round() as i32 as u32, width.round() as u32, height.round() as u32],
            )?;
        }
        self.connection.flush().map_err(error)
    }

    fn set_shortcuts(&self, bindings: &[(Action, KeyCombo)]) -> Vec<Action> {
        let (reply_tx, reply_rx) = mpsc::channel();
        if self.requests.lock().unwrap().send((bindings.to_vec(), reply_tx)).is_err() {
            return bindings.iter().map(|(a, _)| *a).collect();
        }
        reply_rx
            .recv_timeout(Duration::from_secs(2))
            .unwrap_or_else(|_| bindings.iter().map(|(a, _)| *a).collect())
    }

    fn status(&self) -> Status {
        Status {
            kind: "x11",
            ready: true,
            desktop: super::current_desktop(),
            owns_shortcuts: true,
            can_show_overlay: true,
        }
    }

    fn activate(&self, id: u64) {
        let _ = self.send_to_root(id as Window, self.atoms._NET_ACTIVE_WINDOW, [2, 0, 0, 0, 0]);
        let _ = self.connection.flush();
    }
}

fn keysym(key: &str) -> Option<u32> {
    Some(match key {
        k if k.len() == 1 => k.chars().next()? as u32,
        "left" => 0xff51,
        "up" => 0xff52,
        "right" => 0xff53,
        "down" => 0xff54,
        "space" => 0x20,
        "enter" => 0xff0d,
        "tab" => 0xff09,
        "backspace" => 0xff08,
        "delete" => 0xffff,
        "insert" => 0xff63,
        "home" => 0xff50,
        "end" => 0xff57,
        "pageup" => 0xff55,
        "pagedown" => 0xff56,
        "minus" => 0x2d,
        "equal" => 0x3d,
        "bracketleft" => 0x5b,
        "bracketright" => 0x5d,
        "semicolon" => 0x3b,
        "quote" => 0x27,
        "comma" => 0x2c,
        "period" => 0x2e,
        "slash" => 0x2f,
        "backslash" => 0x5c,
        "grave" => 0x60,
        f => 0xffbe + f.strip_prefix('f')?.parse::<u32>().ok()? - 1,
    })
}

fn mod_mask(combo: &KeyCombo) -> u16 {
    let mut mask = 0u16;
    if combo.modifiers.ctrl {
        mask |= u16::from(ModMask::CONTROL);
    }
    if combo.modifiers.alt {
        mask |= u16::from(ModMask::M1);
    }
    if combo.modifiers.shift {
        mask |= u16::from(ModMask::SHIFT);
    }
    if combo.modifiers.logo {
        mask |= u16::from(ModMask::M4);
    }
    mask
}

/// Caps Lock and Num Lock change the modifier state, so every grab is made with and without them.
fn lock_variants() -> [u16; 4] {
    let lock = u16::from(ModMask::LOCK);
    let num = u16::from(ModMask::M2);
    [0, lock, num, lock | num]
}

fn shortcut_thread(
    on_shortcut: OnShortcut,
    requests: mpsc::Receiver<(Vec<(Action, KeyCombo)>, Reply)>,
) -> Result<(), String> {
    let (connection, screen_number) = x11rb::connect(None).map_err(error)?;
    let root = connection.setup().roots[screen_number].root;
    let min = connection.setup().min_keycode;
    let max = connection.setup().max_keycode;
    let mapping = connection.get_keyboard_mapping(min, max - min + 1).map_err(error)?.reply().map_err(error)?;
    let per = mapping.keysyms_per_keycode as usize;
    let keycode_of = |sym: u32| -> Option<u8> {
        mapping.keysyms.chunks(per.max(1)).position(|syms| syms.contains(&sym)).map(|i| min + i as u8)
    };
    let relevant = u16::from(ModMask::CONTROL) | u16::from(ModMask::SHIFT) | u16::from(ModMask::M1) | u16::from(ModMask::M4);
    let mut grabbed: Vec<(u8, u16, Action)> = Vec::new();
    loop {
        while let Ok((bindings, reply)) = requests.try_recv() {
            for (code, mask, _) in grabbed.drain(..) {
                for extra in lock_variants() {
                    let _ = connection.ungrab_key(code, root, ModMask::from(mask | extra));
                }
            }
            let mut failed = Vec::new();
            for (action, combo) in bindings {
                let Some(code) = keysym(&combo.key).and_then(|s| keycode_of(s)) else {
                    failed.push(action);
                    continue;
                };
                let mask = mod_mask(&combo);
                // Another program holding the same keys makes the grab fail with BadAccess.
                let ok = lock_variants().into_iter().all(|extra| {
                    connection
                        .grab_key(true, root, ModMask::from(mask | extra), code, GrabMode::ASYNC, GrabMode::ASYNC)
                        .map(|cookie| cookie.check().is_ok())
                        .unwrap_or(false)
                });
                if ok {
                    grabbed.push((code, mask, action));
                } else {
                    failed.push(action);
                }
            }
            let _ = connection.flush();
            let _ = reply.send(failed);
        }
        match connection.poll_for_event().map_err(error)? {
            Some(Event::KeyPress(event)) => {
                let state = u16::from(event.state) & relevant;
                if let Some((_, _, action)) = grabbed.iter().find(|(code, mask, _)| *code == event.detail && *mask == state) {
                    on_shortcut(*action);
                }
            }
            Some(_) => {}
            None => std::thread::sleep(Duration::from_millis(20)),
        }
    }
}
