// Split for GNOME on Wayland.
//
// Wayland does not let one app move another app's windows, so the Split app asks GNOME Shell
// to do it through this extension over the session D-Bus (name im.runners.Split.Shell, path
// /im/runners/Split/Shell). The app does all the math; this file only reads what is on screen,
// moves windows, and grabs the shortcut keys the app sends.
//
// Coordinates are GNOME Shell's stage coordinates (logical pixels), top-left based.

import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Meta from 'gi://Meta';
import Shell from 'gi://Shell';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

const BUS_NAME = 'im.runners.Split.Shell';
const OBJECT_PATH = '/im/runners/Split/Shell';

const INTERFACE_XML = `
<node>
  <interface name="im.runners.Split.Shell">
    <method name="GetState">
      <arg type="b" direction="in" name="withWindows"/>
      <arg type="s" direction="out" name="json"/>
    </method>
    <method name="GetWorkAreas">
      <arg type="s" direction="out" name="json"/>
    </method>
    <method name="MoveActiveWindow">
      <arg type="i" direction="in" name="x"/>
      <arg type="i" direction="in" name="y"/>
      <arg type="i" direction="in" name="width"/>
      <arg type="i" direction="in" name="height"/>
      <arg type="b" direction="out" name="moved"/>
    </method>
    <method name="MoveWindow">
      <arg type="t" direction="in" name="id"/>
      <arg type="i" direction="in" name="x"/>
      <arg type="i" direction="in" name="y"/>
      <arg type="i" direction="in" name="width"/>
      <arg type="i" direction="in" name="height"/>
      <arg type="b" direction="out" name="moved"/>
    </method>
    <method name="SetShortcuts">
      <arg type="s" direction="in" name="json"/>
      <arg type="s" direction="out" name="failed"/>
    </method>
    <signal name="Activated">
      <arg type="s" name="action"/>
    </signal>
    <property name="Version" type="u" access="read"/>
  </interface>
</node>`;

function rectOf(r) {
    return {x: r.x, y: r.y, width: r.width, height: r.height};
}

function infoOf(win) {
    return {id: win.get_id(), rect: rectOf(win.get_frame_rect()), app: win.get_wm_class() ?? ''};
}

function isOrdinary(win) {
    return win.get_window_type() === Meta.WindowType.NORMAL && !win.minimized && !win.is_skip_taskbar();
}

function isMaximized(win) {
    // GNOME 49 replaced get_maximized() with is_maximized().
    if (typeof win.is_maximized === 'function')
        return win.is_maximized();
    return win.get_maximized() !== 0;
}

function unmaximize(win) {
    try {
        win.unmaximize(Meta.MaximizeFlags.BOTH);
    } catch {
        win.unmaximize();
    }
}

function monitors() {
    const display = global.display;
    const workspace = global.workspace_manager.get_active_workspace();
    const primary = display.get_primary_monitor();
    const result = [];
    for (let i = 0; i < display.get_n_monitors(); i++) {
        result.push({
            frame: rectOf(display.get_monitor_geometry(i)),
            work_area: rectOf(workspace.get_work_area_for_monitor(i)),
            // Stage coordinates are already logical, so gaps need no scaling.
            scale: 1,
            primary: i === primary,
        });
    }
    return result;
}

function findWindow(id) {
    return global.get_window_actors()
        .map(actor => actor.meta_window)
        .find(win => win && win.get_id() === id) ?? null;
}

function moveWindow(win, x, y, width, height) {
    if (!win)
        return false;
    if (win.is_fullscreen())
        win.unmake_fullscreen();
    const wasMaximized = isMaximized(win);
    if (wasMaximized)
        unmaximize(win);
    win.move_resize_frame(true, x, y, width, height);
    if (wasMaximized) {
        // The unmaximize animation can put the old size back; set it once more afterwards.
        GLib.timeout_add(GLib.PRIORITY_DEFAULT, 60, () => {
            win.move_resize_frame(true, x, y, width, height);
            return GLib.SOURCE_REMOVE;
        });
    }
    return true;
}

class SplitService {
    constructor() {
        this._grabs = new Map();
    }

    get Version() {
        return 1;
    }

    GetState(withWindows) {
        const focus = global.display.focus_window;
        const active = focus && isOrdinary(focus) ? infoOf(focus) : null;
        let windows = [];
        if (withWindows) {
            const workspace = global.workspace_manager.get_active_workspace();
            windows = global.display.sort_windows_by_stacking(workspace.list_windows())
                .reverse()
                .filter(isOrdinary)
                .map(infoOf);
        }
        return JSON.stringify({active, screens: monitors(), windows});
    }

    GetWorkAreas() {
        return JSON.stringify(monitors());
    }

    MoveActiveWindow(x, y, width, height) {
        return moveWindow(global.display.focus_window, x, y, width, height);
    }

    MoveWindow(id, x, y, width, height) {
        return moveWindow(findWindow(Number(id)), x, y, width, height);
    }

    /** Grabs {"MoveToLeftHalf": "<Alt><Super>Left", …}; returns the names GNOME would not give. */
    SetShortcuts(json) {
        this.releaseShortcuts();
        const failed = [];
        let wanted = {};
        try {
            wanted = JSON.parse(json);
        } catch (e) {
            logError(e, 'Split: SetShortcuts got bad JSON');
        }
        for (const [name, accelerator] of Object.entries(wanted)) {
            const action = global.display.grab_accelerator(accelerator, Meta.KeyBindingFlags.NONE);
            if (action === Meta.KeyBindingAction.NONE) {
                failed.push(name);
                continue;
            }
            const bindingName = Meta.external_binding_name_for_action(action);
            Main.wm.allowKeybinding(bindingName, Shell.ActionMode.NORMAL | Shell.ActionMode.OVERVIEW);
            this._grabs.set(action, {name, bindingName});
        }
        return JSON.stringify(failed);
    }

    releaseShortcuts() {
        for (const [action, grab] of this._grabs) {
            global.display.ungrab_accelerator(action);
            Main.wm.allowKeybinding(grab.bindingName, Shell.ActionMode.NONE);
        }
        this._grabs.clear();
    }

    activated(action) {
        const grab = this._grabs.get(action);
        if (grab)
            this.dbus?.emit_signal('Activated', new GLib.Variant('(s)', [grab.name]));
    }
}

export default class SplitExtension extends Extension {
    enable() {
        this._service = new SplitService();
        this._service.dbus = Gio.DBusExportedObject.wrapJSObject(INTERFACE_XML, this._service);
        this._service.dbus.export(Gio.DBus.session, OBJECT_PATH);
        this._nameId = Gio.bus_own_name_on_connection(
            Gio.DBus.session, BUS_NAME, Gio.BusNameOwnerFlags.NONE, null, null);
        this._acceleratorId = global.display.connect('accelerator-activated',
            (_display, action) => this._service.activated(action));
    }

    disable() {
        if (this._acceleratorId) {
            global.display.disconnect(this._acceleratorId);
            this._acceleratorId = 0;
        }
        if (this._nameId) {
            Gio.bus_unown_name(this._nameId);
            this._nameId = 0;
        }
        if (this._service) {
            this._service.releaseShortcuts();
            this._service.dbus.unexport();
            this._service = null;
        }
    }
}
