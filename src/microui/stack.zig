const std = @import("std");

pub fn Stack(T: type, size: usize) type {
    return struct {
        idx: usize = 0,
        items: [size]T = undefined,

        pub inline fn push(self: *@This(), item: T) void {
            std.debug.assert(self.idx < self.items.len);
            self.items[self.idx] = item;
            self.idx += 1;
        }

        pub inline fn pop(self: *@This()) T {
            std.debug.assert(self.idx > 0);
            self.idx -= 1;
            return self.items[self.idx];
        }

        pub inline fn top(self: *@This()) T {
            std.debug.assert(self.idx > 0);
            return self.items[self.idx - 1];
        }

        pub inline fn topPtr(self: *@This()) *T {
            std.debug.assert(self.idx > 0);
            return &self.items[self.idx - 1];
        }

        pub inline fn clear(self: *@This()) void {
            self.idx = 0;
        }

        pub inline fn len(self: *const @This()) usize {
            return self.idx;
        }

        pub inline fn isEmpty(self: *const @This()) bool {
            return self.idx == 0;
        }

        pub inline fn slice(self: *@This()) []T {
            return self.items[0..self.idx];
        }
    };
}
