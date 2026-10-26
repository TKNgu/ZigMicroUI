const std = @import("std");

pub fn List(T: type, size: usize) type {
    return struct {
        idx: usize = 0,
        items: [size]T = undefined,

        pub inline fn append(self: *@This(), item: T) void {
            std.debug.assert(self.idx < self.items.len);
            self.items[self.idx] = item;
            self.idx += 1;
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

pub fn Stack(T: type, size: usize) type {
    return struct {
        list: List(T, size) = .{},

        pub fn init() @This() {
            return .{};
        }

        pub inline fn push(self: *@This(), item: T) void {
            self.list.append(item);
        }

        pub inline fn pop(self: *@This()) T {
            std.debug.assert(self.list.idx > 0);
            self.list.idx -= 1;
            return self.list.items[self.list.idx];
        }

        pub inline fn top(self: *const @This()) T {
            std.debug.assert(self.list.idx > 0);
            return self.list.items[self.list.idx - 1];
        }

        pub inline fn topPtr(self: *@This()) *T {
            std.debug.assert(self.list.idx > 0);
            return &self.list.items[self.list.idx - 1];
        }

        pub inline fn clear(self: *@This()) void {
            return self.list.clear();
        }

        pub inline fn len(self: *const @This()) usize {
            return self.list.len();
        }

        pub inline fn isEmpty(self: *const @This()) bool {
            return self.list.isEmpty();
        }

        pub inline fn slice(self: *@This()) []T {
            return self.list.slice();
        }
    };
}
