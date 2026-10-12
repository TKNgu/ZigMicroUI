const std = @import("std");

pub fn BuildStack(T: type, size: usize) type {
    return struct {
        idx: usize = 0,
        items: [size]T = undefined,

        pub fn push(self: *@This(), item: T) void {
            std.debug.assert(self.idx < self.items.len);
            self.items[self.idx] = item;
            self.idx += 1;
        }

        pub fn pop(self: *@This()) T {
            std.debug.assert(self.idx > 0);
            self.idx -= 1;
            return self.items[self.idx];
        }

        pub fn getValue(self: *@This()) T {
            std.debug.assert(self.idx > 0);
            return self.items[self.idx - 1];
        }

        pub fn getPValue(self: *@This()) *T {
            std.debug.assert(self.idx > 0);
            return &self.items[self.idx - 1];
        }

        pub fn clear(self: *@This()) void {
            self.idx = 0;
        }

        pub fn getSlice(self: *@This()) []T {
            return self.items[0..self.idx];
        }

        pub fn getConstSlice(self: *const @This()) []const T {
            return self.items[0..self.idx];
        }
    };
}
