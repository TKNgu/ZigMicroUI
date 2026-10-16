//! MicroUI Generic Fixed-Capacity Stack
//!
//! Cung cấp cấu trúc dữ liệu Stack với kích thước cố định tại thời điểm biên dịch,
//! giúp MicroUI quản lý các tầng Layout, Clipping Rect, ID và Container mà không
//! cần cấp phát động (heap allocation) trong quá trình render mỗi frame.

const std = @import("std");

/// Tạo kiểu Stack có dung lượng tối đa `size` phần tử kiểu `T`.
pub fn BuildStack(T: type, size: usize) type {
    return struct {
        idx: usize = 0,
        items: [size]T = undefined,

        /// Đẩy một phần tử mới lên đỉnh ngăn xếp.
        pub fn push(self: *@This(), item: T) void {
            std.debug.assert(self.idx < self.items.len);
            self.items[self.idx] = item;
            self.idx += 1;
        }

        /// Lấy và xóa phần tử ở đỉnh ngăn xếp.
        pub fn pop(self: *@This()) T {
            std.debug.assert(self.idx > 0);
            self.idx -= 1;
            return self.items[self.idx];
        }

        /// Đọc giá trị phần tử tại đỉnh ngăn xếp mà không xóa.
        pub fn getValue(self: *@This()) T {
            std.debug.assert(self.idx > 0);
            return self.items[self.idx - 1];
        }

        /// Lấy con trỏ đến phần tử tại đỉnh ngăn xếp để chỉnh sửa trực tiếp.
        pub fn getPValue(self: *@This()) *T {
            std.debug.assert(self.idx > 0);
            return &self.items[self.idx - 1];
        }

        /// Đặt lại ngăn xếp về rỗng.
        pub fn clear(self: *@This()) void {
            self.idx = 0;
        }

        /// Lấy slice toàn bộ các phần tử hiện có trong ngăn xếp.
        pub fn getSlice(self: *@This()) []T {
            return self.items[0..self.idx];
        }

        /// Lấy const slice toàn bộ các phần tử hiện có trong ngăn xếp.
        pub fn getConstSlice(self: *const @This()) []const T {
            return self.items[0..self.idx];
        }
    };
}
