const std = @import("std");
const types = @import("types.zig");
pub const Id = types.Id;

pub const PoolItem = struct {
    id: Id = 0,
    last_update: i32 = 0,
};

pub fn Pool(comptime size: usize) type {
    return struct {
        const Self = @This();

        items: [size]PoolItem = [_]PoolItem{.{}} ** size,

        pub fn getIdToIndex(self: *const Self, id: Id) ?usize {
            for (self.items, 0..) |item, i| {
                if (item.id == id) {
                    return i;
                }
            }
            return null;
        }

        pub inline fn update(self: *Self, index: usize, frame: i32) void {
            self.items[index].last_update = frame;
        }

        pub fn alloc(self: *Self, id: Id, frame: i32) usize {
            for (&self.items, 0..) |*item, i| {
                if (item.id == 0) {
                    item.id = id;
                    item.last_update = frame;
                    return i;
                }
            }

            var oldest: i32 = std.math.maxInt(i32);
            var selected: usize = 0;
            for (self.items, 0..) |item, i| {
                if (item.last_update < oldest) {
                    oldest = item.last_update;
                    selected = i;
                }
            }
            self.items[selected].id = id;
            self.items[selected].last_update = frame;
            return selected;
        }

        pub inline fn reset(self: *Self, index: usize) void {
            self.items[index] = .{};
        }
    };
}

pub fn PoolItem2(comptime T: type) type {
    return struct {
        const Self = @This();

        data: T,
        id: Id = 0,
        last_update: i32 = 0,

        pub inline fn init(id: Id, data: T, frame: i32) Self {
            return .{
                .id = id,
                .data = data,
                .last_update = frame,
            };
        }

        pub inline fn refresh(self: *Self, frame: i32) void {
            self.last_update = frame;
        }
    };
}

pub fn Pool2(comptime T: type, comptime size: usize) type {
    return struct {
        const Self = @This();

        items: [size]PoolItem2(T) = [_]PoolItem2(T){.{ .data = .{} }} ** size,

        pub fn get(self: *Self, id: Id) ?*PoolItem2(T) {
            for (&self.items) |*item| {
                if (item.id == id) {
                    return item;
                }
            }
            return null;
        }

        pub fn alloc(self: *Self) *PoolItem2(T) {
            for (&self.items) |*item| {
                if (item.id == 0) {
                    return item;
                }
            }

            var selected: usize = 0;
            var oldest: i32 = self.items[selected].last_update;
            for (self.items[1..], 1..) |item, index| {
                if (item.last_update < oldest) {
                    selected = index;
                    oldest = item.last_update;
                }
            }

            return &self.items[selected];
        }
    };
}
