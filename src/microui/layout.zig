const std = @import("std");
const math = @import("math.zig");
const style_mod = @import("style.zig");
const stack = @import("stack.zig");

pub const MAX_WIDTHS = 16;

pub const NextType = enum {
    none,
    relative,
    absolute,
};

pub const Layout = struct {
    body: math.Rect = .{},
    next: math.Rect = .{},
    position: math.Vec2 = .{},
    size: math.Vec2 = .{},
    max: math.Vec2 = .{},
    widths: [MAX_WIDTHS]i32 = [_]i32{0} ** MAX_WIDTHS,
    items: i32 = 0,
    item_index: i32 = 0,
    next_row: i32 = 0,
    next_type: NextType = .none,
    indent: i32 = 0,

    pub fn init(body: math.Rect, scroll: math.Vec2) Layout {
        return .{
            .body = math.rect(body.x - scroll.x, body.y - scroll.y, body.w, body.h),
            .max = math.vec2(-0x1000000, -0x1000000),
            .widths = [_]i32{0} ** MAX_WIDTHS,
            .items = 1,
        };
    }

    pub fn setRow(self: *Layout, widths: []const i32, height: i32) void {
        std.debug.assert(widths.len <= self.widths.len);
        self.position = math.vec2(self.indent, self.next_row);
        self.size.y = height;
        @memcpy(self.widths[0..widths.len], widths);
        self.items = @intCast(widths.len);
        self.item_index = 0;
        self.next_type = .none;
    }

    pub inline fn setNext(self: *Layout, next: math.Rect, next_type: NextType) void {
        self.next = next;
        self.next_type = next_type;
    }

    pub fn getNext(self: *Layout, style_ptr: *const style_mod.Style) math.Rect {
        var res: math.Rect = .{};

        if (self.next_type != .none) {
            const next_type = self.next_type;
            self.next_type = .none;
            res = self.next;
            if (next_type == .absolute) {
                return res;
            }
        } else {
            if (self.item_index == self.items) {
                self.item_index = 0;
                self.position = math.vec2(self.indent, self.next_row);
            }
            res = .init(
                self.position.x,
                self.position.y,
                if (self.items > 0) self.widths[@intCast(self.item_index)] else self.size.x,
                self.size.y,
            );

            if (res.w == 0) {
                res.w = style_ptr.size.x + style_ptr.padding * 2;
            }
            if (res.h == 0) {
                res.h = style_ptr.size.y + style_ptr.padding * 2;
            }
            if (res.w < 0) {
                res.w += self.body.w - res.x + 1;
            }
            if (res.h < 0) {
                res.h += self.body.h - res.y + 1;
            }
            self.item_index += 1;
        }

        self.position.x += res.w + style_ptr.spacing;
        self.next_row = @max(self.next_row, res.y + res.h + style_ptr.spacing);

        res.x += self.body.x;
        res.y += self.body.y;

        self.max.x = @max(self.max.x, res.x + res.w);
        self.max.y = @max(self.max.y, res.y + res.h);

        return res;
    }
};

pub const LayoutManager = struct {
    layout_stack: stack.Stack(Layout, 16) = .{},

    pub inline fn getCurrent(self: *LayoutManager) *Layout {
        return self.layout_stack.topPtr();
    }

    pub inline fn push(self: *LayoutManager, body: math.Rect, scroll: math.Vec2) void {
        self.layout_stack.push(Layout.init(body, scroll));
    }

    pub inline fn pop(self: *LayoutManager) Layout {
        return self.layout_stack.pop();
    }

    pub inline fn isEmpty(self: *const LayoutManager) bool {
        return self.layout_stack.isEmpty();
    }

    pub inline fn setRow(self: *LayoutManager, widths: []const i32, height: i32) void {
        self.getCurrent().setRow(widths, height);
    }

    pub inline fn setNext(self: *LayoutManager, rect: math.Rect, relative: bool) void {
        self.getCurrent().setNext(rect, if (relative) .relative else .absolute);
    }

    pub inline fn getNext(self: *LayoutManager, style_ptr: *const style_mod.Style) math.Rect {
        return self.getCurrent().getNext(style_ptr);
    }

    pub inline fn beginColumn(self: *LayoutManager, rect: math.Rect) void {
        self.push(rect, math.vec2(0, 0));
    }

    pub fn endColumn(self: *LayoutManager) void {
        const b = self.pop();
        const a = self.getCurrent();
        a.position.x = @max(a.position.x, b.position.x + b.body.x - a.body.x);
        a.next_row = @max(a.next_row, b.next_row + b.body.y - a.body.y);
        a.max.x = @max(a.max.x, b.max.x);
        a.max.y = @max(a.max.y, b.max.y);
    }
};
