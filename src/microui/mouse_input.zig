const std = @import("std");
const math = @import("math.zig");

pub const MouseInput = struct {
    pos: math.Vec2 = .{},
    last_pos: math.Vec2 = .{},
    delta: math.Vec2 = .{},
    scroll_delta: math.Vec2 = .{},
    down: i32 = 0,
    pressed: i32 = 0,

    pub inline fn overlaps(self: *const MouseInput, r: math.Rect) bool {
        return r.contains(self.pos);
    }

    pub inline fn move(self: *MouseInput, x: i32, y: i32) void {
        self.pos = math.vec2(x, y);
    }

    pub inline fn press(self: *MouseInput, x: i32, y: i32, btn: i32) void {
        self.pos = math.vec2(x, y);
        self.down |= btn;
        self.pressed |= btn;
    }

    pub inline fn release(self: *MouseInput, x: i32, y: i32, btn: i32) void {
        self.pos = math.vec2(x, y);
        self.down &= ~btn;
    }

    pub inline fn scroll(self: *MouseInput, x: i32, y: i32) void {
        self.scroll_delta.x += x;
        self.scroll_delta.y += y;
    }

    pub inline fn updateDelta(self: *MouseInput) void {
        self.delta.x = self.pos.x - self.last_pos.x;
        self.delta.y = self.pos.y - self.last_pos.y;
    }

    pub inline fn isDown(self: *const MouseInput, btn: i32) bool {
        return (self.down & btn) != 0;
    }

    pub inline fn isPressed(self: *const MouseInput, btn: i32) bool {
        return (self.pressed & btn) != 0;
    }

    pub inline fn isDownOrPressed(self: *const MouseInput, btn: i32) bool {
        return ((self.down | self.pressed) & btn) != 0;
    }

    pub inline fn hasDown(self: *const MouseInput) bool {
        return self.down != 0;
    }

    pub inline fn hasPressed(self: *const MouseInput) bool {
        return self.pressed != 0;
    }

    pub inline fn getDown(self: *const MouseInput) i32 {
        return self.down;
    }

    pub inline fn getPressed(self: *const MouseInput) i32 {
        return self.pressed;
    }

    pub inline fn end(self: *MouseInput) void {
        self.pressed = 0;
        self.scroll_delta = .{ .x = 0, .y = 0 };
        self.last_pos = self.pos;
    }

    pub inline fn clear(self: *MouseInput) void {
        self.* = .{};
    }
};
