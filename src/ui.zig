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

pub const Layout = struct {
    const VTable = struct {
        next: *const fn (*anyopaque) math.rect.Rect2(f32),

        fn create(comptime T: type) VTable {
            return VTable{
                .next = struct {
                    fn next(ptr: *anyopaque) math.rect.Rect2(f32) {
                        const self: *T = @ptrCast(@alignCast(ptr));
                        return self.next();
                    }
                }.next,
            };
        }
    };

    ptr: *anyopaque,
    vtable: *const VTable,

    pub inline fn next(self: *const Layout) math.rect.Rect2(f32) {
        return self.vtable.*.next(self.ptr);
    }
};

pub fn createRowLayout(comptime N: usize) type {
    return struct {
        const Self = @This();
        const VTable = Layout.VTable.create(Self);

        body: math.rect.Rect2(f32),
        layout: createArrayLayout(N),

        pub fn init(body: math.rect.Rect2(f32), heights: *const [N]f32) Self {
            return .{
                .body = body,
                .layout = createArrayLayout(N).init(heights),
            };
        }

        pub inline fn getBase(self: *Self) Layout {
            return Layout{ .ptr = self, .vtable = &Self.VTable };
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
        const VTable = Layout.VTable.create(Self);

        body: math.rect.Rect2(f32),
        layout: createArrayLayout(N),

        pub fn init(body: math.rect.Rect2(f32), widths: *const [N]f32) Self {
            return .{
                .body = body,
                .layout = createArrayLayout(N).init(widths),
            };
        }

        pub inline fn getBase(self: *Self) Layout {
            return Layout{ .ptr = self, .vtable = &Self.VTable };
        }

        pub fn next(self: *Self) math.rect.Rect2(f32) {
            var width = self.layout.next();
            if (width < 0) {
                width += self.body.getWidth();
            } else if (width == 0) {
                width = self.body.getWidth();
            }
            const rect = math.rect.Rect2(f32).initVec(
                self.body.pos,
                math.vec.Vec2(f32).init(width, self.body.getHeight()),
            );
            self.body.pos.selfAdd(math.vec.Vec2(f32).init(width, 0));
            self.body.size.selfSub(math.vec.Vec2(f32).init(width, 0));
            return rect;
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
