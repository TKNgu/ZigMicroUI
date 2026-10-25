const std = @import("std");
const types = @import("types.zig");
const mouse = @import("mouse_input.zig");
const math = @import("math.zig");

const Opt = types.Opt;
const Id = types.Id;
pub const MouseInput = mouse.MouseInput;

const MouseState = struct {
    hasDown: bool = false,
    pressed: i32 = 0,
};

const IdLogic = struct {
    mouse_state: MouseState = .{},
    hover: Id = 0,
    focus: Id = 0,
    updated_focus: bool = false,

    pub fn setMouseState(self: *IdLogic, mouse_state: MouseState) void {
        self.mouse_state = mouse_state;
    }

    pub fn update(
        self: *IdLogic,
        mouse_over: bool,
        id: Id,
        opt: i32,
    ) void {
        if (self.focus == id) {
            self.updated_focus = true;
        }
        if (Opt.has(opt, .no_interact)) {
            return;
        }

        if (mouse_over and !self.mouse_state.hasDown) {
            self.hover = id;
        }

        if (self.focus == id) {
            if (self.mouse_state.hasDown and !mouse_over) {
                self.setFocus(0);
            }
            if (!self.mouse_state.hasDown and !Opt.has(opt, .hold_focus)) {
                self.setFocus(0);
            }
        }

        if (self.hover == id) {
            if (self.mouse_state.hasDown) {
                self.setFocus(id);
            } else if (!mouse_over) {
                self.hover = 0;
            }
        }
    }

    pub fn commitState(self: *IdLogic) void {
        if (!self.updated_focus) {
            self.focus = 0;
        }
        self.updated_focus = false;
    }

    pub inline fn setFocus(self: *IdLogic, id: Id) void {
        self.focus = id;
        self.updated_focus = true;
    }
};

pub const InputControl = struct {
    id_logic: IdLogic = .{},
    mouse_input: MouseInput = .{},

    pub fn setFocus(self: *InputControl, id: Id) void {
        self.id_logic.setFocus(id);
    }

    pub fn updateControl(self: *InputControl, id: Id, mouseover: bool, opt: i32) void {
        self.id_logic.setMouseState(.{
            .hasDown = self.mouse_input.hasDown(),
            .pressed = self.mouse_input.getPressed(),
        });
        self.id_logic.update(mouseover, id, opt);
    }

    pub inline fn endFrame(self: *InputControl) void {
        self.id_logic.commitState();
        self.mouse_input.end();
    }

    pub inline fn inputMouseMove(self: *InputControl, x: i32, y: i32) void {
        self.mouse_input.move(math.Vec2.init(x, y));
    }

    pub inline fn inputScroll(self: *InputControl, x: i32, y: i32) void {
        self.mouse_input.scroll(math.Vec2.init(x, y));
    }

    pub inline fn inputMouseDown(self: *InputControl, x: i32, y: i32, btn: types.Mouse) void {
        self.mouse_input.press(math.Vec2.init(x, y), btn);
    }

    pub inline fn inputMouseUp(self: *InputControl, x: i32, y: i32, btn: types.Mouse) void {
        self.mouse_input.release(math.Vec2.init(x, y), btn);
    }

    pub inline fn updateMouseDelta(self: *InputControl) void {
        self.mouse_input.updateDelta();
    }

    pub inline fn mouseOver(self: *const InputControl, r: math.Rect) bool {
        return self.mouse_input.overlaps(r);
    }

    pub inline fn isMouseDown(self: *const InputControl, btn: types.Mouse) bool {
        return self.mouse_input.isDown(btn);
    }

    pub inline fn isDownOrPressed(self: *const InputControl, btn: types.Mouse) bool {
        return self.mouse_input.isDownOrPressed(btn);
    }

    pub inline fn getMouseDelta(self: *const InputControl) math.Vec2 {
        return self.mouse_input.delta;
    }

    pub inline fn getMousePos(self: *const InputControl) math.Vec2 {
        return self.mouse_input.pos;
    }

    pub inline fn getScrollDelta(self: *const InputControl) math.Vec2 {
        return self.mouse_input.scroll_delta;
    }

    pub inline fn isPressed(self: *const InputControl, btn: types.Mouse) bool {
        return self.mouse_input.isPressed(btn);
    }

    pub inline fn hasPressed(self: *const InputControl) bool {
        return self.mouse_input.hasPressed();
    }
};
