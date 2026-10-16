//! MicroUI Math Module
//!
//! Cung cấp các cấu trúc hình học cơ bản (Vec2, Rect) và các hàm toán học
//! phục vụ tính toán layout, clipping và hit-testing trong hệ thống UI.

/// Vector 2 chiều đại diện cho toạ độ điểm (x, y) hoặc kích thước (width, height) kiểu số nguyên i32.
pub const Vec2 = extern struct {
    x: i32 = 0,
    y: i32 = 0,

    /// Khởi tạo Vec2 với toạ độ x, y.
    pub fn init(x: i32, y: i32) Vec2 {
        return .{ .x = x, .y = y };
    }
};

/// Hàm tiện ích tạo nhanh Vec2.
pub fn vec2(x: i32, y: i32) Vec2 {
    return Vec2.init(x, y);
}

/// Hình chữ nhật đại diện cho vị trí (x, y) và kích thước (w, h) của một thành phần UI.
pub const Rect = extern struct {
    x: i32 = 0,
    y: i32 = 0,
    w: i32 = 0,
    h: i32 = 0,

    /// Khởi tạo Rect với toạ độ và kích thước cụ thể.
    pub fn init(x: i32, y: i32, w: i32, h: i32) Rect {
        return .{ .x = x, .y = y, .w = w, .h = h };
    }

    /// Mở rộng hình chữ nhật về cả 4 phía một khoảng `n` pixel.
    pub fn expand(self: Rect, n: i32) Rect {
        return .{
            .x = self.x - n,
            .y = self.y - n,
            .w = self.w + n * 2,
            .h = self.h + n * 2,
        };
    }

    /// Tính phần giao nhau giữa 2 hình chữ nhật (dùng trong tính toán vùng cắt clip).
    pub fn intersect(r1: Rect, r2: Rect) Rect {
        const x1 = @max(r1.x, r2.x);
        const y1 = @max(r1.y, r2.y);
        const x2 = @min(r1.x + r1.w, r2.x + r2.w);
        const y2 = @min(r1.y + r1.h, r2.y + r2.h);
        if (x2 < x1 or y2 < y1) {
            return .{ .x = x1, .y = y1, .w = 0, .h = 0 };
        } else {
            return .{ .x = x1, .y = y1, .w = x2 - x1, .h = y2 - y1 };
        }
    }

    /// Kiểm tra toạ độ điểm `p` có nằm bên trong hình chữ nhật hay không.
    pub fn overlapsVec2(self: Rect, p: Vec2) bool {
        return p.x >= self.x and p.x < self.x + self.w and p.y >= self.y and p.y < self.y + self.h;
    }
};

/// Hàm tiện ích tạo nhanh Rect.
pub fn rect(x: i32, y: i32, w: i32, h: i32) Rect {
    return Rect.init(x, y, w, h);
}
