//! MicroUI Style & Theme Module
//!
//! Quản lý màu sắc, kích thước lề/đệm và giao diện tổng thể của hệ thống UI.

const std = @import("std");
const math = @import("math.zig");
const Vec2 = math.Vec2;

/// Đại diện kiểu con trỏ font mờ (opaque pointer), tương thích với backend render đồ họa.
pub const Font = ?*anyopaque;

/// Cấu trúc màu RGBA chuẩn 32-bit (mỗi kênh 8-bit).
pub const Color = extern struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
    a: u8 = 255,

    /// Khởi tạo màu với đầy đủ các kênh R, G, B, A.
    pub fn init(r: u8, g: u8, b: u8, a: u8) Color {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    /// Khởi tạo màu RGB với độ mờ mặc định (alpha = 255).
    pub fn rgb(r: u8, g: u8, b: u8) Color {
        return .{ .r = r, .g = g, .b = b, .a = 255 };
    }
};

/// Hàm tiện ích tạo nhanh Color.
pub const color = Color.init;
pub const rgb = Color.rgb;

/// Định danh các màu sắc trong bảng theme giao diện MicroUI.
pub const ColorId = enum(i32) {
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

    pub fn toInt(self: ColorId) i32 {
        return @intFromEnum(self);
    }

    pub fn toIndex(self: ColorId) usize {
        return @intCast(@intFromEnum(self));
    }
};

// Các hằng số định danh màu để truy cập nhanh
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

/// Bảng màu mặc định theo phong cách tối thanh lịch.
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

/// Cấu hình phong cách và thông số kích thước giao diện.
pub const Style = extern struct {
    font: Font = null,
    size: Vec2 = .{ .x = 68, .y = 10 },
    padding: i32 = 5,
    spacing: i32 = 4,
    indent: i32 = 24,
    title_height: i32 = 24,
    scrollbar_size: i32 = 12,
    thumb_size: i32 = 8,
    colors: [ColorId.count]Color = default_colors,

    /// Lấy màu tương ứng với ColorId.
    pub fn getColor(self: *const Style, id: ColorId) Color {
        return self.colors[id.toIndex()];
    }

    /// Thiết lập màu tương ứng với ColorId.
    pub fn setColor(self: *Style, id: ColorId, c: Color) void {
        self.colors[id.toIndex()] = c;
    }
};

/// Phong cách mặc định của toàn hệ thống.
pub const default_style: Style = .{};
