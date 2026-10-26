const std = @import("std");
const id_manager = @import("../microui/id_manager.zig");

const MicroUI = @import("../microui/microui.zig").MicroUI;
const widget = @import("../microui/widget.zig");

pub fn clearWindow(microui: *MicroUI) !void {
    if (!try widget.Window.begin(
        microui,
        "Clear Window",
        MicroUI.Rect.init(100, 100, 300, 200),
        .{},
    )) {
        return;
    }
    defer widget.Window.end(microui);
}
