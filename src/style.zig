const color = @import("color.zig");

pub const Style = struct {
    background_color: color.Color = color.Nord.background,
    window_color: color.Color = color.DebugHighContrast.background,
    window_border_color: color.Color = color.DebugHighContrast.border,

    window_titlebar_size: f32 = 24,
    window_titlebar_color: color.Color = color.DebugHighContrast.titlebar,
    window_titlebar_border_color: color.Color = color.DebugHighContrast.border,

    button_color: color.Color = color.DebugHighContrast.button,

    window_statusbar_size: f32 = 24,
    window_statusbar_color: color.Color = color.DebugHighContrast.panel,
    window_statusbar_border_color: color.Color = color.DebugHighContrast.border,
};
