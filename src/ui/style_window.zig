const std = @import("std");
const MicroUI = @import("../microui/microui.zig").MicroUI;
const widget = @import("../microui/widget.zig");

pub fn styleWindow(microui: *MicroUI) !void {
    if (!(try widget.Window.begin(microui, "Style Editor", MicroUI.Rect.init(350, 250, 300, 240), .{}))) return;
    defer widget.Window.end(microui);

    const body_w = microui.getCurrentContainer().body.w;
    const size_width: i32 = @intFromFloat(@as(f32, @floatFromInt(body_w)) * 0.14);
    microui.setLayoutRow(&[_]i32{ 80, size_width, size_width, size_width, size_width, -1 }, 0);

    const style_ptr = microui.getStyle();
    inline for (std.enums.values(MicroUI.ColorId)) |color_id| {
        const c = style_ptr.getColorPtr(color_id);
        try widget.Label.label(microui, @tagName(color_id));
        _ = try widget.Slider.uint8Slider(microui, &c.r, 0, 255);
        _ = try widget.Slider.uint8Slider(microui, &c.g, 0, 255);
        _ = try widget.Slider.uint8Slider(microui, &c.b, 0, 255);
        _ = try widget.Slider.uint8Slider(microui, &c.a, 0, 255);
        try microui.drawRect(microui.layoutNext(), c.*);
    }
}
