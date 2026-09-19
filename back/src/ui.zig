const std = @import("std");
const math = @import("math.zig");
const render = @import("render.zig");
const color = @import("color.zig");
const style = @import("style.zig");

// Draw
pub fn drawFrame(
    renderer: *render.RenderEngine,
    rect: math.rect.Rect2(f32),
    rect_color: color.Color,
    border_color: color.Color,
) !void {
    try renderer.fillRect(rect, rect_color);
    try renderer.rect(rect, border_color);
}

pub fn drawFrawWithoutBorder(
    renderer: *render.RenderEngine,
    frame_rect: math.rect.Rect2(f32),
    draw_color: color.Color,
) !void {
    try renderer.fillRect(frame_rect, draw_color);
}

// Layout
pub fn createArrayLayout(comptime N: usize) type {
    return struct {
        const Self = @This();

        index: usize = 0,
        items: [N]f32 = undefined,

        pub fn init(items: *const [N]f32) Self {
            var layout: Self = .{};
            std.mem.copyForwards(f32, &layout.items, items);
            return layout;
        }

        pub fn next(self: *Self) f32 {
            if (self.index >= N) {
                self.index = 0;
            }
            const item = self.items[self.index];
            self.index += 1;
            return item;
        }

        pub inline fn getIsEnd(self: *const Self) bool {
            return self.index >= N;
        }

        pub inline fn nextLine(self: *Self) void {
            self.index = 0;
        }
    };
}

pub fn createRowLayout(comptime N: usize) type {
    return struct {
        const Self = @This();

        body: math.rect.Rect2(f32),
        layout: createArrayLayout(N),

        pub fn init(body: math.rect.Rect2(f32), heights: *const [N]f32) Self {
            return .{
                .body = body,
                .layout = createArrayLayout(N).init(heights),
            };
        }

        pub fn next(self: *Self) math.rect.Rect2(f32) {
            var height = self.layout.next();
            if (height < 0) {
                height += self.body.getHeight();
            } else if (height == 0) {
                height = self.body.getHeight();
            }
            const rect = math.rect.Rect2(f32).initVec(
                self.body.pos,
                math.vec.Vec2(f32).init(self.body.getWidth(), height),
            );
            self.body.pos.selfAdd(math.vec.Vec2(f32).init(0, height));
            self.body.size.selfSub(math.vec.Vec2(f32).init(0, height));
            return rect;
        }
    };
}

pub fn createColumnLayout(comptime N: usize) type {
    return struct {
        const Self = @This();

        position: math.vec.Vec2(f32),
        width: f32,
        width_layout: createArrayLayout(N),
        body: math.rect.Rect2(f32),
        row_height: f32 = 0,

        pub fn init(position: math.vec.Vec2(f32), width: f32, widths: *const [N]f32) Self {
            return .{
                .position = position,
                .width = width,
                .width_layout = createArrayLayout(N).init(widths),
                .body = math.rect.Rect2(f32).initVec(
                    position,
                    math.vec.Vec2(f32).init(width, 0),
                ),
            };
        }

        pub fn next(self: *Self, height: f32) math.rect.Rect2(f32) {
            var item_width = self.width_layout.next();
            if (item_width < 0) {
                const sum_width = self.position.x - self.body.getX();
                item_width += self.body.getWidth() - sum_width;
            } else if (item_width == 0) {
                const sum_width = self.position.x - self.body.getX();
                item_width = self.body.getWidth() - sum_width;
            }

            const item_height = if (self.row_height < height) UPDATE_HEIGHT: {
                self.body.addHeight(height - self.row_height);
                self.row_height = height;
                break :UPDATE_HEIGHT height;
            } else self.row_height;

            const item_rect = math.rect.Rect2(f32).initVec(
                self.position,
                math.vec.Vec2(f32).init(item_width, item_height),
            );

            if (self.width_layout.getIsEnd()) {
                self.position = math.vec.Vec2(f32).init(
                    self.body.getX(),
                    self.body.getY() + self.body.getHeight(),
                );
                self.row_height = 0;
            } else {
                self.position.x += item_width;
            }

            return item_rect;
        }
    };
}

// ID

pub const ID = u32;
pub const HASH_INITIAL: ID = 2166136261;

pub fn hash(id: *ID, data: []const u8) void {
    for (data) |c| {
        id.* = (id.* ^ c) *% 16777619;
    }
}

pub fn sourceLocationToString(comptime s: std.builtin.SourceLocation) []const u8 {
    return std.fmt.comptimePrint("{d}:{d}:{s}:{s}", .{
        s.column,
        s.line,
        s.file,
        s.module,
    });
}

pub fn genSrcLineID(id: *ID, comptime s: std.builtin.SourceLocation) ID {
    hash(id, sourceLocationToString(s));
    return id.*;
}

pub const IdLogic = struct {
    pub const State = enum {
        normal,
        hover,
        mouse_down,
        mouse_up,
    };

    last_hover_id: ?ID = null,
    down_id: ?ID = null,
    hover_id: ?ID = null,
    is_mouse_down: bool = false,

    pub fn begin(self: *IdLogic, is_mouse_down: bool) void {
        self.is_mouse_down = is_mouse_down;
        self.hover_id = null;
    }

    pub fn update(self: *IdLogic, id: ID, is_contain: bool) State {
        if (self.is_mouse_down) {
            if (self.down_id != null) {
                return if (self.down_id == id) .mouse_down else .normal;
            }
            if (self.last_hover_id == id) {
                self.down_id = id;
                return .mouse_down;
            }
            return .normal;
        }
        if (!is_contain) {
            return .normal;
        }
        if (self.down_id == id) {
            return .mouse_up;
        }
        self.hover_id = id;
        return .hover;
    }

    pub fn end(self: *IdLogic) void {
        self.last_hover_id = self.hover_id;
        if (!self.is_mouse_down) {
            self.down_id = null;
        }
    }
};

pub const ClipStack = struct {
    stack: [32]math.rect.Rect2(f32),
    index: usize,

    pub fn init(clip: math.rect.Rect2(f32)) ClipStack {
        var self: ClipStack = undefined;
        self.stack[0] = clip;
        self.index = 0;
        return self;
    }

    pub fn max(a: anytype, b: anytype) @TypeOf(a) {
        return if (a > b) a else b;
    }

    pub fn min(a: anytype, b: anytype) @TypeOf(a) {
        return if (a < b) a else b;
    }

    pub fn containRect(rect_a: math.rect.Rect2(f32), rect_b: math.rect.Rect2(f32)) math.rect.Rect2(f32) {
        const x = max(rect_a.pos.x, rect_b.pos.x);
        const y = max(rect_a.pos.y, rect_b.pos.y);
        const w = min(rect_a.pos.x + rect_a.size.x, rect_b.pos.x + rect_b.size.x) - x;
        const h = min(rect_a.pos.y + rect_a.size.y, rect_b.pos.y + rect_b.size.y) - y;
        return math.rect.Rect2(f32).init(x, y, w, h);
    }

    pub fn push(self: *ClipStack, clip: math.rect.Rect2(f32)) !math.rect.Rect2(f32) {
        if (self.index >= self.stack.len - 1) {
            return error.ClipStackOverflow;
        }
        self.index += 1;
        self.stack[self.index] =
            containRect(clip, self.stack[self.index - 1]);
        return self.top();
    }

    pub fn pop(self: *ClipStack) !math.rect.Rect2(f32) {
        if (self.index == 0) {
            return error.ClipStackUnderflow;
        }
        self.index -= 1;
        return self.stack[self.index];
    }

    pub fn top(self: ClipStack) math.rect.Rect2(f32) {
        return self.stack[self.index];
    }
};
