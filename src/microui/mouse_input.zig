const std = @import("std");
const math = @import("math.zig");
const types = @import("types.zig");
const Mouse = types.Mouse;

pub const MouseInput = struct {
    pos: math.Vec2 = .zero,
    last_pos: math.Vec2 = .zero,
    delta: math.Vec2 = .zero,
    scroll_delta: math.Vec2 = .zero,
    down: i32 = 0,
    pressed: i32 = 0,

    pub inline fn overlaps(self: *const MouseInput, r: math.Rect) bool {
        return r.contains(self.pos);
    }

    pub inline fn move(self: *MouseInput, pos: math.Vec2) void {
        self.pos = pos;
    }

    pub inline fn press(self: *MouseInput, pos: math.Vec2, btn: Mouse) void {
        self.pos = pos;
        self.down |= btn.toInt();
        self.pressed |= btn.toInt();
    }

    pub inline fn release(self: *MouseInput, pos: math.Vec2, btn: Mouse) void {
        self.pos = pos;
        self.down &= ~btn.toInt();
    }

    pub inline fn scroll(self: *MouseInput, value: math.Vec2) void {
        self.scroll_delta.add(value);
    }

    pub inline fn updateDelta(self: *MouseInput) void {
        self.delta = self.pos.subVec2(self.last_pos);
    }

    pub inline fn isDown(self: *const MouseInput, btn: Mouse) bool {
        return (self.down & btn.toInt()) != 0;
    }

    pub inline fn isPressed(self: *const MouseInput, btn: Mouse) bool {
        return (self.pressed & btn.toInt()) != 0;
    }

    pub inline fn isDownOrPressed(self: *const MouseInput, btn: Mouse) bool {
        return ((self.down | self.pressed) & btn.toInt()) != 0;
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
