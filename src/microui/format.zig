//! MicroUI Text & Numeric Formatting Utilities
//!
//! Hỗ trợ định dạng số thực (f32) thành chuỗi null-terminated theo chuỗi định dạng (vd: "%.2f", "%.0f").

const std = @import("std");

/// Định dạng số thực (f32) thành chuỗi kết thúc bằng null theo định dạng printf (ví dụ: "%.2f", "%.0f").
pub fn formatReal(buf: []u8, fmt: [*c]const u8, val: f32) [:0]const u8 {
    if (buf.len == 0) return "";
    const span = if (fmt != null) std.mem.span(fmt) else "";
    var precision: ?usize = null;
    if (std.mem.indexOfScalar(u8, span, '.')) |dot_idx| {
        var p: usize = 0;
        var i = dot_idx + 1;
        while (i < span.len and std.ascii.isDigit(span[i])) : (i += 1) {
            p = p * 10 + (span[i] - '0');
        }
        if (i > dot_idx + 1) {
            precision = p;
        }
    }
    if (precision) |prec| {
        return switch (prec) {
            0 => std.fmt.bufPrintSentinel(buf, "{d:.0}", .{val}, 0) catch "",
            1 => std.fmt.bufPrintSentinel(buf, "{d:.1}", .{val}, 0) catch "",
            2 => std.fmt.bufPrintSentinel(buf, "{d:.2}", .{val}, 0) catch "",
            3 => std.fmt.bufPrintSentinel(buf, "{d:.3}", .{val}, 0) catch "",
            4 => std.fmt.bufPrintSentinel(buf, "{d:.4}", .{val}, 0) catch "",
            5 => std.fmt.bufPrintSentinel(buf, "{d:.5}", .{val}, 0) catch "",
            else => std.fmt.bufPrintSentinel(buf, "{d:.2}", .{val}, 0) catch "",
        };
    } else {
        return std.fmt.bufPrintSentinel(buf, "{d}", .{val}, 0) catch "";
    }
}
