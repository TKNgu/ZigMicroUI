const std = @import("std");
const c_microui = @import("c_microui");
const math = @import("math.zig");
const Vec2 = math.Vec2;

pub const Font = ?*anyopaque;

pub const Color = extern struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
    a: u8 = 255,

    pub fn init(r: u8, g: u8, b: u8, a: u8) Color {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn rgb(r: u8, g: u8, b: u8) Color {
        return .{ .r = r, .g = g, .b = b, .a = 255 };
    }

    pub fn toMu(self: Color) c_microui.mu_Color {
        return .{ .r = self.r, .g = self.g, .b = self.b, .a = self.a };
    }

    pub fn fromMu(c: c_microui.mu_Color) Color {
        return .{ .r = c.r, .g = c.g, .b = c.b, .a = c.a };
    }
};

pub fn color(r: u8, g: u8, b: u8, a: u8) Color {
    return Color.init(r, g, b, a);
}

pub fn rgb(r: u8, g: u8, b: u8) Color {
    return Color.rgb(r, g, b);
}

pub const ColorId = enum(c_int) {
    text = 0,
    border = 1,
    window_bg = 2,
    title_bg = 3,
    title_text = 4,
    panel_bg = 5,
    button = 6,
    button_hover = 7,
    button_focus = 8,
    base = 9,
    base_hover = 10,
    base_focus = 11,
    scroll_base = 12,
    scroll_thumb = 13,

    pub const count: usize = 14;

    pub const text_idx: usize = 0;
    pub const border_idx: usize = 1;
    pub const window_bg_idx: usize = 2;
    pub const title_bg_idx: usize = 3;
    pub const title_text_idx: usize = 4;
    pub const panel_bg_idx: usize = 5;
    pub const button_idx: usize = 6;
    pub const button_hover_idx: usize = 7;
    pub const button_focus_idx: usize = 8;
    pub const base_idx: usize = 9;
    pub const base_hover_idx: usize = 10;
    pub const base_focus_idx: usize = 11;
    pub const scroll_base_idx: usize = 12;
    pub const scroll_thumb_idx: usize = 13;

    pub fn toInt(self: ColorId) c_int {
        return @intFromEnum(self);
    }

    pub fn toIndex(self: ColorId) usize {
        return @intCast(@intFromEnum(self));
    }
};

pub const COLOR_TEXT = ColorId.text.toInt();
pub const COLOR_BORDER = ColorId.border.toInt();
pub const COLOR_WINDOWBG = ColorId.window_bg.toInt();
pub const COLOR_TITLEBG = ColorId.title_bg.toInt();
pub const COLOR_TITLETEXT = ColorId.title_text.toInt();
pub const COLOR_PANELBG = ColorId.panel_bg.toInt();
pub const COLOR_BUTTON = ColorId.button.toInt();
pub const COLOR_BUTTONHOVER = ColorId.button_hover.toInt();
pub const COLOR_BUTTONFOCUS = ColorId.button_focus.toInt();
pub const COLOR_BASE = ColorId.base.toInt();
pub const COLOR_BASEHOVER = ColorId.base_hover.toInt();
pub const COLOR_BASEFOCUS = ColorId.base_focus.toInt();
pub const COLOR_SCROLLBASE = ColorId.scroll_base.toInt();
pub const COLOR_SCROLLTHUMB = ColorId.scroll_thumb.toInt();

pub const default_colors = [ColorId.count]Color{
    Color.init(230, 230, 230, 255), // text
    Color.init(25, 25, 25, 255),    // border
    Color.init(50, 50, 50, 255),    // window_bg
    Color.init(25, 25, 25, 255),    // title_bg
    Color.init(240, 240, 240, 255), // title_text
    Color.init(0, 0, 0, 0),         // panel_bg
    Color.init(75, 75, 75, 255),    // button
    Color.init(95, 95, 95, 255),    // button_hover
    Color.init(115, 115, 115, 255), // button_focus
    Color.init(30, 30, 30, 255),    // base
    Color.init(35, 35, 35, 255),    // base_hover
    Color.init(40, 40, 40, 255),    // base_focus
    Color.init(43, 43, 43, 255),    // scroll_base
    Color.init(30, 30, 30, 255),    // scroll_thumb
};

pub const Style = extern struct {
    font: Font = null,
    size: Vec2 = .{ .x = 68, .y = 10 },
    padding: c_int = 5,
    spacing: c_int = 4,
    indent: c_int = 24,
    title_height: c_int = 24,
    scrollbar_size: c_int = 12,
    thumb_size: c_int = 8,
    colors: [ColorId.count]Color = default_colors,

    pub fn getColor(self: *const Style, id: ColorId) Color {
        return self.colors[id.toIndex()];
    }

    pub fn setColor(self: *Style, id: ColorId, c: Color) void {
        self.colors[id.toIndex()] = c;
    }

    pub fn toMu(self: *const Style) *const c_microui.mu_Style {
        return @ptrCast(self);
    }

    pub fn fromMu(s: *c_microui.mu_Style) *Style {
        return @ptrCast(s);
    }
};

pub const default_style: Style = .{};

comptime {
    std.debug.assert(@sizeOf(Color) == @sizeOf(c_microui.mu_Color));
    std.debug.assert(@alignOf(Color) == @alignOf(c_microui.mu_Color));
    std.debug.assert(@sizeOf(Style) == @sizeOf(c_microui.mu_Style));
    std.debug.assert(@alignOf(Style) == @alignOf(c_microui.mu_Style));
}
