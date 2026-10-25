const std = @import("std");
const math = @import("math.zig");
const Vec2 = math.Vec2;

pub const Font = ?*anyopaque;

pub const Color = extern struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
    a: u8 = 255,

    pub inline fn init(r: u8, g: u8, b: u8, a: u8) Color {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    pub inline fn rgb(r: u8, g: u8, b: u8) Color {
        return .{ .r = r, .g = g, .b = b, .a = 255 };
    }
};

pub const ColorId = enum(i32) {
    pub const count: usize = @typeInfo(ColorId).@"enum".fields.len;

    text = 0,
    border,
    window_bg,
    title_bg,
    title_text,
    panel_bg,
    button,
    button_hover,
    button_focus,
    base,
    base_hover,
    base_focus,
    scroll_base,
    scroll_thumb,

    pub inline fn toInt(self: ColorId) i32 {
        return @intFromEnum(self);
    }
};

pub const ColorList = std.enums.EnumArray(ColorId, Color);

pub const default_colors: ColorList = ColorList.init(.{
    .text = Color.init(230, 230, 230, 255),
    .border = Color.init(25, 25, 25, 255),
    .window_bg = Color.init(50, 50, 50, 255),
    .title_bg = Color.init(25, 25, 25, 255),
    .title_text = Color.init(240, 240, 240, 255),
    .panel_bg = Color.init(0, 0, 0, 0),
    .button = Color.init(75, 75, 75, 255),
    .button_hover = Color.init(95, 95, 95, 255),
    .button_focus = Color.init(115, 115, 115, 255),
    .base = Color.init(30, 30, 30, 255),
    .base_hover = Color.init(35, 35, 35, 255),
    .base_focus = Color.init(40, 40, 40, 255),
    .scroll_base = Color.init(43, 43, 43, 255),
    .scroll_thumb = Color.init(30, 30, 30, 255),
});

pub const Style = struct {
    font: Font = null,
    size: Vec2 = .init(68, 10),
    padding: i32 = 5,
    spacing: i32 = 4,
    indent: i32 = 24,
    title_height: i32 = 24,
    scrollbar_size: i32 = 12,
    thumb_size: i32 = 8,
    colors: ColorList = default_colors,

    pub inline fn getColor(self: *const Style, id: ColorId) Color {
        return self.colors.get(id);
    }

    pub inline fn getColorPtr(self: *Style, id: ColorId) *Color {
        return self.colors.getPtr(id);
    }

    pub inline fn setColor(self: *Style, id: ColorId, c: Color) void {
        self.colors.set(id, c);
    }
};

pub const default_style: Style = .{};
