const microui = @import("sdl.zig").microui;

pub const defaultStype: microui.mu_Style = .{
    .font = null,
    .size = .{ .x = 68, .y = 10 },
    .padding = 5,
    .spacing = 4,
    .indent = 24,
    .title_height = 24,
    .scrollbar_size = 12,
    .thumb_size = 8,
    .colors = .{
        .{ .r = 230, .g = 230, .b = 230, .a = 255 },
        .{ .r = 25, .g = 25, .b = 25, .a = 255 },
        .{ .r = 50, .g = 50, .b = 50, .a = 255 },
        .{ .r = 25, .g = 25, .b = 25, .a = 255 },
        .{ .r = 240, .g = 240, .b = 240, .a = 255 },
        .{ .r = 0, .g = 0, .b = 0, .a = 0 },
        .{ .r = 75, .g = 75, .b = 75, .a = 255 },
        .{ .r = 95, .g = 95, .b = 95, .a = 255 },
        .{ .r = 115, .g = 115, .b = 115, .a = 255 },
        .{ .r = 30, .g = 30, .b = 30, .a = 255 },
        .{ .r = 35, .g = 35, .b = 35, .a = 255 },
        .{ .r = 40, .g = 40, .b = 40, .a = 255 },
        .{ .r = 43, .g = 43, .b = 43, .a = 255 },
        .{ .r = 30, .g = 30, .b = 30, .a = 255 },
    },
};
