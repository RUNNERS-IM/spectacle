// Split for KDE Plasma on Wayland.
//
// Wayland does not let one app move another app's windows, so KWin does it with this script.
// KWin scripts can call D-Bus but cannot be called, so the script owns the shortcuts: when one
// is pressed it sends what is on screen to the Split app (D-Bus name im.runners.Split), which
// answers where each window goes, using the same math as the macOS app. Then the script moves
// them.
//
// Change the keys in System Settings › Shortcuts › KWin (search for "Split").

const SERVICE = "im.runners.Split";
const PATH = "/im/runners/Split";
const INTERFACE = "im.runners.Split";

// Same defaults as the macOS app, with ⌘ as Meta (the Super / Windows key).
const SHORTCUTS = [
    ["MoveToCenter", "Center", "Meta+Alt+C"],
    ["MoveToFullscreen", "Full Screen", "Meta+Alt+F"],
    ["MoveToLeftHalf", "Left Half", "Meta+Alt+Left"],
    ["MoveToRightHalf", "Right Half", "Meta+Alt+Right"],
    ["MoveToTopHalf", "Top Half", "Meta+Alt+Up"],
    ["MoveToBottomHalf", "Bottom Half", "Meta+Alt+Down"],
    ["MoveToUpperLeft", "Top Left", "Meta+Ctrl+Left"],
    ["MoveToLowerLeft", "Bottom Left", "Meta+Ctrl+Shift+Left"],
    ["MoveToUpperRight", "Top Right", "Meta+Ctrl+Right"],
    ["MoveToLowerRight", "Bottom Right", "Meta+Ctrl+Shift+Right"],
    ["MoveToNextDisplay", "Next Display", "Meta+Ctrl+Alt+Right"],
    ["MoveToPreviousDisplay", "Previous Display", "Meta+Ctrl+Alt+Left"],
    ["MoveToNextThird", "Next Third", "Ctrl+Alt+Right"],
    ["MoveToPreviousThird", "Previous Third", "Ctrl+Alt+Left"],
    ["MakeLarger", "Larger", "Ctrl+Alt+Shift+Right"],
    ["MakeSmaller", "Smaller", "Ctrl+Alt+Shift+Left"],
    ["UndoLastMove", "Undo", "Meta+Alt+Z"],
    ["RedoLastMove", "Redo", "Meta+Alt+Shift+Z"],
    ["ArrangeWindows", "Arrange All Windows", "Meta+Alt+A"],
];

function rectOf(r) {
    return { x: r.x, y: r.y, width: r.width, height: r.height };
}

// Plasma 6 renamed activeClient → activeWindow and clientList() → stackingOrder.
function activeWindow() {
    return workspace.activeWindow !== undefined ? workspace.activeWindow : workspace.activeClient;
}

function stackingOrder() {
    return workspace.stackingOrder !== undefined ? workspace.stackingOrder : workspace.clientList();
}

function onCurrentDesktop(w) {
    if (w.onAllDesktops) return true;
    const current = workspace.currentDesktop;
    if (w.desktops !== undefined) {
        for (let i = 0; i < w.desktops.length; i++) {
            if (w.desktops[i] === current) return true;
        }
        return false;
    }
    return w.desktop === current || w.desktop === -1;
}

function isOwnWindow(w) {
    const name = String(w.resourceClass || "").toLowerCase();
    return name === "split" || name === "im.runners.split";
}

function isOrdinary(w) {
    return w && w.normalWindow && !w.minimized && !w.skipTaskbar && onCurrentDesktop(w) && !isOwnWindow(w);
}

function screens() {
    const result = [];
    if (workspace.screens !== undefined) {
        const outputs = workspace.screens;
        for (let i = 0; i < outputs.length; i++) {
            const output = outputs[i];
            result.push({
                frame: rectOf(output.geometry),
                work_area: rectOf(workspace.clientArea(KWin.MaximizeArea, output, workspace.currentDesktop)),
                scale: 1,
                primary: i === 0,
            });
        }
    } else {
        for (let i = 0; i < workspace.numScreens; i++) {
            result.push({
                frame: rectOf(workspace.clientArea(KWin.ScreenArea, i, workspace.currentDesktop)),
                work_area: rectOf(workspace.clientArea(KWin.MaximizeArea, i, workspace.currentDesktop)),
                scale: 1,
                primary: i === 0,
            });
        }
    }
    return result;
}

function moveWindow(w, rect) {
    if (w.fullScreen) w.fullScreen = false;
    if (typeof w.setMaximize === "function") w.setMaximize(false, false);
    w.frameGeometry = { x: rect.x, y: rect.y, width: rect.width, height: rect.height };
}

function run(action) {
    const active = activeWindow();
    // The app only sees positions in this list, so window ids are indexes.
    const known = [];
    const stack = stackingOrder();
    for (let i = stack.length - 1; i >= 0; i--) {
        if (isOrdinary(stack[i])) known.push(stack[i]);
    }
    let activeId = known.indexOf(active);
    if (active && activeId < 0 && !isOwnWindow(active)) {
        known.push(active);
        activeId = known.length - 1;
    }
    const info = (w, id) => ({ id: id, rect: rectOf(w.frameGeometry), app: String(w.resourceClass || "") });
    const state = {
        active: activeId >= 0 ? info(active, activeId) : null,
        screens: screens(),
        windows: action === "ArrangeWindows" ? known.map(info) : [],
    };
    callDBus(SERVICE, PATH, INTERFACE, "Plan", action, JSON.stringify(state), function (reply) {
        let outcome;
        try {
            outcome = JSON.parse(reply);
        } catch (e) {
            print("Split: unexpected reply: " + reply);
            return;
        }
        for (const move of outcome.moves || []) {
            const w = known[move.id];
            if (w) moveWindow(w, move.rect);
        }
    });
}

for (const [action, title, keys] of SHORTCUTS) {
    registerShortcut("Split: " + action, "Split: " + title, keys, function () {
        run(action);
    });
}
