//! Windows: shortcuts with RegisterHotKey, windows and monitors through Win32.
//!
//! All coordinates are physical pixels. Tauri makes the process per-monitor DPI aware (v2), so
//! Win32 reports real pixels on every monitor; each screen's `scale` turns the gap into pixels.

use std::ffi::c_void;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::mpsc;
use std::sync::{Arc, Mutex};
use std::time::Duration;

use split_core::shortcuts::KeyCombo;
use split_core::{Action, Move, Rect, Screen, Snapshot, WindowInfo};
use windows_sys::Win32::Foundation::{CloseHandle, BOOL, HWND, LPARAM, RECT};
use windows_sys::Win32::Graphics::Dwm::{DwmGetWindowAttribute, DWMWA_CLOAKED, DWMWA_EXTENDED_FRAME_BOUNDS};
use windows_sys::Win32::Graphics::Gdi::{
    EnumDisplayMonitors, GetMonitorInfoW, MonitorFromWindow, HDC, HMONITOR, MONITORINFO, MONITOR_DEFAULTTONEAREST,
};
use windows_sys::Win32::System::Threading::{
    GetCurrentProcessId, GetCurrentThreadId, OpenProcess, QueryFullProcessImageNameW, PROCESS_NAME_WIN32,
    PROCESS_QUERY_LIMITED_INFORMATION,
};
use windows_sys::Win32::UI::HiDpi::{GetDpiForMonitor, MDT_EFFECTIVE_DPI};
use windows_sys::Win32::UI::Input::KeyboardAndMouse::{
    RegisterHotKey, UnregisterHotKey, MOD_ALT, MOD_CONTROL, MOD_NOREPEAT, MOD_SHIFT, MOD_WIN,
};
use windows_sys::Win32::UI::WindowsAndMessaging::{
    EnumWindows, GetClassNameW, GetForegroundWindow, GetMessageW, GetWindow, GetWindowLongPtrW, GetWindowRect,
    GetWindowTextLengthW, GetWindowThreadProcessId, IsIconic, IsWindow, IsWindowVisible, IsZoomed, PeekMessageW,
    PostThreadMessageW, SetForegroundWindow, SetWindowLongPtrW, SetWindowPos, ShowWindow, GWL_EXSTYLE, GW_OWNER,
    HWND_TOPMOST, MONITORINFOF_PRIMARY, MSG, PM_NOREMOVE, SWP_NOACTIVATE, SWP_NOMOVE, SWP_NOOWNERZORDER, SWP_NOSIZE, SWP_NOZORDER,
    SWP_SHOWWINDOW, SW_RESTORE, SW_SHOWNOACTIVATE, WM_APP, WM_HOTKEY, WM_USER, WS_EX_NOACTIVATE, WS_EX_TOOLWINDOW,
    WS_EX_TRANSPARENT,
};

use super::{Backend, OnShortcut, Status};

type Reply = mpsc::Sender<Vec<Action>>;

pub struct WindowsBackend {
    thread_id: u32,
    requests: Mutex<mpsc::Sender<(Vec<(Action, KeyCombo)>, Reply)>>,
    /// The last window of another app that had the focus. Choosing an action from the tray
    /// menu gives the focus to the taskbar first, so that action goes to this window instead.
    last_foreground: Arc<AtomicU64>,
}

fn hwnd_of(id: u64) -> HWND {
    id as isize as HWND
}

fn id_of(hwnd: HWND) -> u64 {
    hwnd as isize as u64
}

fn rect_of(r: &RECT) -> Rect {
    Rect::new(r.left as f64, r.top as f64, (r.right - r.left) as f64, (r.bottom - r.top) as f64)
}

/// The window as people see it. Since Windows 10, GetWindowRect includes an invisible resize
/// border of about 7 px on the left, right and bottom; DWM knows the visible part.
fn visible_rect(hwnd: HWND) -> Option<Rect> {
    let mut frame: RECT = unsafe { std::mem::zeroed() };
    let ok = unsafe {
        DwmGetWindowAttribute(
            hwnd,
            DWMWA_EXTENDED_FRAME_BOUNDS as _,
            &mut frame as *mut RECT as *mut c_void,
            std::mem::size_of::<RECT>() as u32,
        )
    } == 0;
    if ok {
        return Some(rect_of(&frame));
    }
    let mut outer: RECT = unsafe { std::mem::zeroed() };
    (unsafe { GetWindowRect(hwnd, &mut outer) } != 0).then(|| rect_of(&outer))
}

fn is_cloaked(hwnd: HWND) -> bool {
    let mut cloaked: u32 = 0;
    let ok = unsafe {
        DwmGetWindowAttribute(
            hwnd,
            DWMWA_CLOAKED as _,
            &mut cloaked as *mut u32 as *mut c_void,
            std::mem::size_of::<u32>() as u32,
        )
    } == 0;
    ok && cloaked != 0
}

fn process_id(hwnd: HWND) -> u32 {
    let mut pid = 0u32;
    unsafe { GetWindowThreadProcessId(hwnd, &mut pid) };
    pid
}

/// The program file of the window's process; undo history is kept per program, as on macOS.
fn app_of(hwnd: HWND) -> String {
    let pid = process_id(hwnd);
    let handle = unsafe { OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, 0, pid) };
    if handle.is_null() {
        return format!("pid:{pid}");
    }
    let mut buffer = [0u16; 1024];
    let mut length = buffer.len() as u32;
    let ok = unsafe { QueryFullProcessImageNameW(handle, PROCESS_NAME_WIN32, buffer.as_mut_ptr(), &mut length) } != 0;
    unsafe { CloseHandle(handle) };
    if ok {
        String::from_utf16_lossy(&buffer[..length as usize])
    } else {
        format!("pid:{pid}")
    }
}

fn class_name(hwnd: HWND) -> String {
    let mut buffer = [0u16; 256];
    let length = unsafe { GetClassNameW(hwnd, buffer.as_mut_ptr(), buffer.len() as i32) };
    String::from_utf16_lossy(&buffer[..length.max(0) as usize])
}

/// The taskbar, the desktop and other shell parts are never moved.
fn is_shell_window(hwnd: HWND) -> bool {
    matches!(
        class_name(hwnd).as_str(),
        "Shell_TrayWnd" | "Shell_SecondaryTrayWnd" | "Progman" | "WorkerW" | "Windows.UI.Core.CoreWindow"
    )
}

fn window_info(hwnd: HWND) -> Option<WindowInfo> {
    if hwnd.is_null() || is_shell_window(hwnd) || process_id(hwnd) == unsafe { GetCurrentProcessId() } {
        return None;
    }
    Some(WindowInfo { id: id_of(hwnd), rect: visible_rect(hwnd)?, app: app_of(hwnd) })
}

/// A window someone would call "a window": visible, not minimized, not a tool palette or
/// popup that belongs to another window, not hidden on another virtual desktop.
fn is_ordinary(hwnd: HWND) -> bool {
    unsafe {
        if IsWindowVisible(hwnd) == 0 || IsIconic(hwnd) != 0 || !GetWindow(hwnd, GW_OWNER).is_null() {
            return false;
        }
        let ex_style = GetWindowLongPtrW(hwnd, GWL_EXSTYLE) as u32;
        if ex_style & WS_EX_TOOLWINDOW != 0 || ex_style & WS_EX_NOACTIVATE != 0 {
            return false;
        }
        GetWindowTextLengthW(hwnd) > 0 && !is_cloaked(hwnd)
    }
}

unsafe extern "system" fn collect_window(hwnd: HWND, data: LPARAM) -> BOOL {
    let list = &mut *(data as *mut Vec<HWND>);
    list.push(hwnd);
    1
}

/// Top-level windows front to back (EnumWindows walks the Z order from the top).
fn ordinary_windows() -> Vec<WindowInfo> {
    let mut handles: Vec<HWND> = Vec::new();
    unsafe { EnumWindows(Some(collect_window), &mut handles as *mut Vec<HWND> as LPARAM) };
    handles.into_iter().filter(|h| is_ordinary(*h)).filter_map(window_info).collect()
}

unsafe extern "system" fn collect_monitor(monitor: HMONITOR, _dc: HDC, _clip: *mut RECT, data: LPARAM) -> BOOL {
    let list = &mut *(data as *mut Vec<Screen>);
    let mut info: MONITORINFO = std::mem::zeroed();
    info.cbSize = std::mem::size_of::<MONITORINFO>() as u32;
    if GetMonitorInfoW(monitor, &mut info) != 0 {
        let mut dpi_x = 96u32;
        let mut dpi_y = 96u32;
        if GetDpiForMonitor(monitor, MDT_EFFECTIVE_DPI, &mut dpi_x, &mut dpi_y) != 0 {
            dpi_x = 96;
        }
        list.push(Screen {
            frame: rect_of(&info.rcMonitor),
            work_area: rect_of(&info.rcWork),
            scale: dpi_x as f64 / 96.0,
            primary: info.dwFlags & MONITORINFOF_PRIMARY != 0,
        });
    }
    1
}

fn screens() -> Vec<Screen> {
    let mut list: Vec<Screen> = Vec::new();
    unsafe {
        EnumDisplayMonitors(std::ptr::null_mut(), std::ptr::null(), Some(collect_monitor), &mut list as *mut Vec<Screen> as LPARAM)
    };
    list
}

fn vk_code(key: &str) -> Option<u32> {
    let single = |c: char| Some(c.to_ascii_uppercase() as u32);
    Some(match key {
        k if k.len() == 1 => return single(k.chars().next()?),
        "left" => 0x25,
        "up" => 0x26,
        "right" => 0x27,
        "down" => 0x28,
        "space" => 0x20,
        "enter" => 0x0D,
        "tab" => 0x09,
        "backspace" => 0x08,
        "delete" => 0x2E,
        "insert" => 0x2D,
        "home" => 0x24,
        "end" => 0x23,
        "pageup" => 0x21,
        "pagedown" => 0x22,
        "minus" => 0xBD,
        "equal" => 0xBB,
        "bracketleft" => 0xDB,
        "bracketright" => 0xDD,
        "semicolon" => 0xBA,
        "quote" => 0xDE,
        "comma" => 0xBC,
        "period" => 0xBE,
        "slash" => 0xBF,
        "backslash" => 0xDC,
        "grave" => 0xC0,
        f => {
            let n: u32 = f.strip_prefix('f')?.parse().ok()?;
            0x70 + n - 1
        }
    })
}

fn modifiers_of(combo: &KeyCombo) -> u32 {
    let mut value = MOD_NOREPEAT;
    if combo.modifiers.ctrl {
        value |= MOD_CONTROL;
    }
    if combo.modifiers.alt {
        value |= MOD_ALT;
    }
    if combo.modifiers.shift {
        value |= MOD_SHIFT;
    }
    if combo.modifiers.logo {
        value |= MOD_WIN;
    }
    value
}

/// The shortcut thread: owns the hot keys (Windows ties them to the thread that registered
/// them) and runs a message loop that hears WM_HOTKEY.
fn shortcut_thread(
    on_shortcut: OnShortcut,
    requests: mpsc::Receiver<(Vec<(Action, KeyCombo)>, Reply)>,
    ready: mpsc::Sender<u32>,
) {
    let mut msg: MSG = unsafe { std::mem::zeroed() };
    // Why: a thread gets a message queue on its first message call; PostThreadMessageW fails before that.
    unsafe { PeekMessageW(&mut msg, std::ptr::null_mut(), WM_USER, WM_USER, PM_NOREMOVE) };
    let _ = ready.send(unsafe { GetCurrentThreadId() });
    let mut registered: Vec<Action> = Vec::new();
    loop {
        let result = unsafe { GetMessageW(&mut msg, std::ptr::null_mut(), 0, 0) };
        if result <= 0 {
            break;
        }
        match msg.message {
            WM_HOTKEY => {
                if let Some(action) = registered.get(msg.wParam.wrapping_sub(1)) {
                    on_shortcut(*action);
                }
            }
            WM_APP => {
                while let Ok((bindings, reply)) = requests.try_recv() {
                    for index in 0..registered.len() {
                        unsafe { UnregisterHotKey(std::ptr::null_mut(), index as i32 + 1) };
                    }
                    registered.clear();
                    let mut failed = Vec::new();
                    for (action, combo) in bindings {
                        let id = registered.len() as i32 + 1;
                        let ok = vk_code(&combo.key)
                            .is_some_and(|vk| unsafe { RegisterHotKey(std::ptr::null_mut(), id, modifiers_of(&combo), vk) } != 0);
                        // Keep the slot either way so ids stay in step with `registered`.
                        registered.push(action);
                        if !ok {
                            failed.push(action);
                        }
                    }
                    let _ = reply.send(failed);
                }
            }
            _ => {}
        }
    }
}

impl WindowsBackend {
    pub fn start(on_shortcut: OnShortcut) -> Self {
        let (request_tx, request_rx) = mpsc::channel();
        let (ready_tx, ready_rx) = mpsc::channel();
        std::thread::Builder::new()
            .name("split-shortcuts".into())
            .spawn(move || shortcut_thread(on_shortcut, request_rx, ready_tx))
            .expect("failed to start the shortcut thread");
        let thread_id = ready_rx.recv().expect("the shortcut thread starts");
        let last_foreground = Arc::new(AtomicU64::new(0));
        let remembered = last_foreground.clone();
        std::thread::Builder::new()
            .name("split-foreground".into())
            .spawn(move || loop {
                let foreground = unsafe { GetForegroundWindow() };
                if !foreground.is_null() && window_info(foreground).is_some() {
                    remembered.store(id_of(foreground), Ordering::Relaxed);
                }
                std::thread::sleep(Duration::from_millis(250));
            })
            .expect("failed to start the foreground thread");
        Self { thread_id, requests: Mutex::new(request_tx), last_foreground }
    }

    /// Makes the highlight window click-through and unable to take the keyboard focus, then
    /// shows it on top without activating it.
    pub fn show_overlay(hwnd: isize) {
        let hwnd = hwnd as HWND;
        unsafe {
            let ex_style = GetWindowLongPtrW(hwnd, GWL_EXSTYLE) as u32;
            SetWindowLongPtrW(hwnd, GWL_EXSTYLE, (ex_style | WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW | WS_EX_TRANSPARENT) as isize);
            ShowWindow(hwnd, SW_SHOWNOACTIVATE);
            SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_SHOWWINDOW);
        }
    }
}

impl Backend for WindowsBackend {
    fn snapshot(&self, with_windows: bool) -> Result<Snapshot, String> {
        let foreground = unsafe { GetForegroundWindow() };
        let active = window_info(foreground).or_else(|| {
            let remembered = hwnd_of(self.last_foreground.load(Ordering::Relaxed));
            (!remembered.is_null() && unsafe { IsWindow(remembered) } != 0 && unsafe { IsIconic(remembered) } == 0)
                .then(|| window_info(remembered))
                .flatten()
        });
        Ok(Snapshot {
            active,
            screens: screens(),
            windows: if with_windows { ordinary_windows() } else { Vec::new() },
        })
    }

    fn apply(&self, moves: &[Move]) -> Result<(), String> {
        for item in moves {
            let hwnd = hwnd_of(item.id);
            unsafe {
                if IsZoomed(hwnd) != 0 || IsIconic(hwnd) != 0 {
                    ShowWindow(hwnd, SW_RESTORE);
                }
            }
            let monitor_before = unsafe { MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST) };
            let place = |hwnd: HWND| {
                // Turn the visible rect we want into the outer rect Win32 sets, invisible borders included.
                let (Some(visible), Some(outer)) = (visible_rect(hwnd), {
                    let mut r: RECT = unsafe { std::mem::zeroed() };
                    (unsafe { GetWindowRect(hwnd, &mut r) } != 0).then(|| rect_of(&r))
                }) else {
                    return false;
                };
                let left = visible.x - outer.x;
                let top = visible.y - outer.y;
                let right = outer.max_x() - visible.max_x();
                let bottom = outer.max_y() - visible.max_y();
                let r = item.rect;
                unsafe {
                    SetWindowPos(
                        hwnd,
                        std::ptr::null_mut(),
                        (r.x - left).round() as i32,
                        (r.y - top).round() as i32,
                        (r.width + left + right).round() as i32,
                        (r.height + top + bottom).round() as i32,
                        SWP_NOZORDER | SWP_NOACTIVATE | SWP_NOOWNERZORDER,
                    ) != 0
                }
            };
            if !place(hwnd) {
                return Err(format!("could not move window {:#x}", item.id));
            }
            // Why: moving to a monitor with another DPI makes the app rescale itself after the
            // first move, so the size is set once more on the new monitor.
            let monitor_after = unsafe { MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST) };
            if monitor_after != monitor_before {
                place(hwnd);
            }
        }
        Ok(())
    }

    fn set_shortcuts(&self, bindings: &[(Action, KeyCombo)]) -> Vec<Action> {
        let (reply_tx, reply_rx) = mpsc::channel();
        let sent = self.requests.lock().unwrap().send((bindings.to_vec(), reply_tx)).is_ok()
            && unsafe { PostThreadMessageW(self.thread_id, WM_APP, 0, 0) } != 0;
        if !sent {
            return bindings.iter().map(|(a, _)| *a).collect();
        }
        reply_rx
            .recv_timeout(std::time::Duration::from_secs(2))
            .unwrap_or_else(|_| bindings.iter().map(|(a, _)| *a).collect())
    }

    fn status(&self) -> Status {
        Status {
            kind: "windows",
            ready: true,
            desktop: "Windows".into(),
            owns_shortcuts: true,
            can_show_overlay: true,
        }
    }

    fn activate(&self, id: u64) {
        unsafe { SetForegroundWindow(hwnd_of(id)) };
    }
}
