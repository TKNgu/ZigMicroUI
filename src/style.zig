const color = @import("color.zig");

pub const Style = struct {
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
