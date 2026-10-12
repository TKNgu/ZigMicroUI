const MicroUI = @import("../microui/microui.zig").MicroUI;
const uint8Slider = @import("../microui/slider.zig").uint8Slider;

pub fn styleWindow(microui: *MicroUI) !void {
    if (!microui.beginWindow("Style Editor", MicroUI.Rect.init(350, 250, 300, 240))) return;
    defer microui.endWindow();

    const ColorSlider = struct {
        label: [:0]const u8,
        idx: usize,
    };

    const colors = [_]ColorSlider{
        .{ .label = "text", .idx = MicroUI.ColorId.text_idx },
        .{ .label = "border", .idx = MicroUI.ColorId.border_idx },
        .{ .label = "windowbg", .idx = MicroUI.ColorId.window_bg_idx },
        .{ .label = "titlebg", .idx = MicroUI.ColorId.title_bg_idx },
        .{ .label = "titletext", .idx = MicroUI.ColorId.title_text_idx },
        .{ .label = "panelbg", .idx = MicroUI.ColorId.panel_bg_idx },
        .{ .label = "button", .idx = MicroUI.ColorId.button_idx },
        .{ .label = "buttonhover", .idx = MicroUI.ColorId.button_hover_idx },
        .{ .label = "buttonfocus", .idx = MicroUI.ColorId.button_focus_idx },
        .{ .label = "base", .idx = MicroUI.ColorId.base_idx },
        .{ .label = "basehover", .idx = MicroUI.ColorId.base_hover_idx },
        .{ .label = "basefocus", .idx = MicroUI.ColorId.base_focus_idx },
        .{ .label = "scrollbase", .idx = MicroUI.ColorId.scroll_base_idx },
        .{ .label = "scrollthumb", .idx = MicroUI.ColorId.scroll_thumb_idx },
    };

    const size_width: i32 =
        @intFromFloat(@as(f32, @floatFromInt(microui.getCurrentContainer().*.body.w)) * 0.14);
    microui.layoutRow(&[_]i32{ 80, size_width, size_width, size_width, size_width, -1 }, 0);

    const style_ptr = microui.getStyle();
    for (colors) |color| {
        microui.drawLabel(color.label);
        _ = uint8Slider(microui, &style_ptr.colors[color.idx].r, 0, 255);
        _ = uint8Slider(microui, &style_ptr.colors[color.idx].g, 0, 255);
        _ = uint8Slider(microui, &style_ptr.colors[color.idx].b, 0, 255);
        _ = uint8Slider(microui, &style_ptr.colors[color.idx].a, 0, 255);
        microui.drawRect(microui.layoutNext(), style_ptr.colors[color.idx]);
    }
}
