const color = @import("color.zig");
const math = @import("math.zig");

pub const Style = struct {
    size: math.vec.Vec2(f32) = .{ .x = 68, .y = 10 },
    padding: u32 = 5,
    spacing: u32 = 4,
    indent: u32 = 24,

    title_height: u32 = 24,
    scrollbar_size: u32 = 12,
    thumb_size: u32 = 8,

    color_text: color.Color = .{ .r = 230, .g = 230, .b = 230, .a = 255 },
    color_border: color.Color = .{ .r = 25, .g = 25, .b = 25, .a = 255 },
    color_windowbg: color.Color = .{ .r = 50, .g = 50, .b = 50, .a = 255 },
    color_titlebg: color.Color = .{ .r = 25, .g = 25, .b = 25, .a = 255 },
    color_titletext: color.Color = .{ .r = 240, .g = 240, .b = 240, .a = 255 },
    color_panelbg: color.Color = .{ .r = 0, .g = 0, .b = 0, .a = 0 },
    color_button: color.Color = .{ .r = 75, .g = 75, .b = 75, .a = 255 },
    color_buttonhover: color.Color = .{ .r = 95, .g = 95, .b = 95, .a = 255 },
    color_buttonfocus: color.Color = .{ .r = 115, .g = 115, .b = 115, .a = 255 },
    color_base: color.Color = .{ .r = 30, .g = 30, .b = 30, .a = 255 },
    color_basehover: color.Color = .{ .r = 35, .g = 35, .b = 35, .a = 255 },
    color_basefocus: color.Color = .{ .r = 40, .g = 40, .b = 40, .a = 255 },
    color_scrollbase: color.Color = .{ .r = 43, .g = 43, .b = 43, .a = 255 },
    color_scrollthumb: color.Color = .{ .r = 30, .g = 30, .b = 30, .a = 255 },

    // Button
    button_size: f32 = 24,
    button_border_size: f32 = 2,

    // Window
    background_color: color.Color = color.Nord.background,
    window_color: color.Color = color.DebugHighContrast.background,
    window_border_color: color.Color = color.DebugHighContrast.border,

    window_titlebar_size: f32 = 24,
    window_titlebar_color: color.Color = color.DebugHighContrast.titlebar,
    window_titlebar_border_color: color.Color = color.DebugHighContrast.border,

    window_titlebar_title_color: color.Color = color.DebugHighContrast.text,

    button_color: color.Color = color.DebugHighContrast.button,

    window_body_color: color.Color = color.DebugHighContrast.background,
    window_body_border_color: color.Color = color.DebugHighContrast.border,

    window_statusbar_size: f32 = 24,
    window_statusbar_color: color.Color = color.DebugHighContrast.panel,
    window_statusbar_border_color: color.Color = color.DebugHighContrast.border,
    window_statusbar_title_color: color.Color = color.DebugHighContrast.text,

    // Menu
    menu_size: f32 = 16,
    menu_color: color.Color = color.DebugHighContrast.panel2,
    menu_border_color: color.Color = color.DebugHighContrast.border,
    menu_text_color: color.Color = color.DebugHighContrast.button,

    // Text
    text_color: color.Color = color.DebugHighContrast.text,
    border_color: color.Color = color.DebugHighContrast.border,

    // Border
    normal_border_color: color.Color = color.Nord.border,
    hover_border_color: color.Color = color.DebugHighContrast.border,
    focus_border_color: color.Color = color.DebugHighContrast.border,
};
