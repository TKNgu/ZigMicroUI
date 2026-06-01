const std = @import("std");

pub const vec = struct {
    pub fn Vec2(comptime T: type) type {
        return struct {
            x: T,
            y: T,

            pub inline fn init(x: T, y: T) Vec2(@TypeOf(x)) {
                return .{
                    .x = x,
                    .y = y,
                };
            }

            pub inline fn selfAdd(self: *@This(), b: @This()) void {
                self.x += b.x;
                self.y += b.y;
            }

            pub inline fn selfSub(self: *@This(), b: @This()) void {
                self.x -= b.x;
                self.y -= b.y;
            }

            pub inline fn add(self: *@This(), b: @This()) @This() {
                return .{
                    .x = self.x + b.x,
                    .y = self.y + b.y,
                };
            }

            pub inline fn sub(self: *@This(), b: @This()) @This() {
                return .{
                    .x = self.x - b.x,
                    .y = self.y - b.y,
                };
            }
        };
    }
};

pub const rect = struct {
    pub fn Rect2(comptime T: type) type {
        return struct {
            pos: vec.Vec2(T),
            size: vec.Vec2(T),

            pub inline fn init(x: T, y: T, w: T, h: T) Rect2(@TypeOf(x)) {
                return .{
                    .pos = vec.Vec2(T).init(x, y),
                    .size = vec.Vec2(T).init(w, h),
                };
            }

            pub inline fn initVec(pos: vec.Vec2(T), size: vec.Vec2(T)) Rect2(@TypeOf(pos.x)) {
                return .{
                    .pos = pos,
                    .size = size,
                };
            }

            pub inline fn getWidth(self: Rect2(T)) T {
                return self.size.x;
            }

            pub inline fn getHeight(self: Rect2(T)) T {
                return self.size.y;
            }

            pub inline fn getX(self: Rect2(T)) T {
                return self.pos.x;
            }

            pub inline fn getY(self: Rect2(T)) T {
                return self.pos.y;
            }

            pub inline fn contains(self: Rect2(T), point: vec.Vec2(T)) bool {
                return self.pos.x <= point.x and self.pos.x + self.size.x >= point.x and
                    self.pos.y <= point.y and self.pos.y + self.size.y >= point.y;
            }
        };
    }
};
