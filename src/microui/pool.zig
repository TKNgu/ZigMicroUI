const std = @import("std");
pub const Id = @import("types.zig").Id;

pub fn PoolItem(comptime T: type) type {
    return struct {
        const Self = @This();

        data: T,
        id: Id = 0,
        last_update: i32 = 0,

        pub inline fn init(data: T, id: Id, frame: i32) Self {
            return .{
                .data = data,
                .id = id,
                .last_update = frame,
            };
        }

        pub inline fn refresh(self: *Self, frame: i32) void {
            self.last_update = frame;
        }

        pub inline fn reset(self: *Self) void {
            self.id = 0;
        }
    };
}

pub fn Pool(comptime T: type, comptime size: usize) type {
    return struct {
        const Self = @This();

        items: [size]PoolItem(T) = [_]PoolItem(T){.{ .data = .{} }} ** size,

        pub fn get(self: *Self, id: Id) ?*PoolItem(T) {
            for (&self.items) |*item| {
                if (item.id == id) {
                    return item;
                }
            }
            return null;
        }

        pub fn alloc(self: *Self) *PoolItem(T) {
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

        pub fn allocAndInit(self: *Self, data: T, id: Id, frame: i32) *PoolItem(T) {
            const item = self.alloc();
            item.* = .init(data, id, frame);
            return item;
        }
    };
}
