const c_microui = @import("c_microui");
const MicroUI = @import("../microui/microui.zig").MicroUI;
const uint8Slider = @import("../microui/slider.zig").uint8Slider;

pub fn styleWindow(microui: *MicroUI) !void {
    if (!microui.beginWindow("Style Editor", c_microui.mu_rect(350, 250, 300, 240))) return;
    defer microui.endWindow();

    const ColorSlider = struct {
        label: [:0]const u8,
        idx: usize,
    };

    const colors = [_]ColorSlider{
        .{ .label = "text"[0..], .idx = c_microui.MU_COLOR_TEXT },
        .{ .label = "border", .idx = c_microui.MU_COLOR_BORDER },
        .{ .label = "windowbg", .idx = c_microui.MU_COLOR_WINDOWBG },
        .{ .label = "titlebg", .idx = c_microui.MU_COLOR_TITLEBG },
        .{ .label = "titletext", .idx = c_microui.MU_COLOR_TITLETEXT },
        .{ .label = "panelbg", .idx = c_microui.MU_COLOR_PANELBG },
        .{ .label = "button", .idx = c_microui.MU_COLOR_BUTTON },
        .{ .label = "buttonhover", .idx = c_microui.MU_COLOR_BUTTONHOVER },
        .{ .label = "buttonfocus", .idx = c_microui.MU_COLOR_BUTTONFOCUS },
        .{ .label = "base", .idx = c_microui.MU_COLOR_BASE },
        .{ .label = "basehover", .idx = c_microui.MU_COLOR_BASEHOVER },
        .{ .label = "basefocus", .idx = c_microui.MU_COLOR_BASEFOCUS },
        .{ .label = "scrollbase", .idx = c_microui.MU_COLOR_SCROLLBASE },
        .{ .label = "scrollthumb", .idx = c_microui.MU_COLOR_SCROLLTHUMB },
    };

    const size_width: i32 =
        @intFromFloat(@as(f32, @floatFromInt(microui.getCurrentContainer().*.body.w)) * 0.14);
    microui.layoutRow(&[_]i32{ 80, size_width, size_width, size_width, size_width, -1 }, 0);

    const ctx = microui.mu_context;
    var ctx_colors = ctx.*.style.*.colors[0..];
    for (colors, 0..) |color, index| {
        microui.drawLabel(color.label);
        _ = uint8Slider(microui, &ctx_colors[index].r, 0, 255);
        _ = uint8Slider(microui, &ctx_colors[index].g, 0, 255);
        _ = uint8Slider(microui, &ctx_colors[index].b, 0, 255);
        _ = uint8Slider(microui, &ctx_colors[index].a, 0, 255);
        microui.drawRect(microui.layoutNext(), ctx_colors[index]);
    }
}
