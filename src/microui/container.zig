const std = @import("std");
const math = @import("math.zig");
const command = @import("command.zig");
const stack = @import("stack.zig");
const Pool2 = @import("pool.zig").Pool2;
const types = @import("types.zig");

pub const Id = types.Id;
pub const Opt = types.Opt;

pub const Container = struct {
    head: ?*command.Command = null,
    tail: ?*command.Command = null,
    rect: math.Rect = .{},
    body: math.Rect = .{},
    content_size: math.Vec2 = .{},
    scroll: math.Vec2 = .{},
    zindex: i32 = 0,
    open: i32 = 0,

    pub inline fn isRoot(self: *const Container) bool {
        return self.head != null;
    }
};

fn compareContainersByZIndex(_: void, a: *Container, b: *Container) bool {
    return a.zindex < b.zindex;
}

pub const ContainerManager = struct {
    containers: Pool2(Container, 48) = .{},

    last_zindex: i32 = 0,
    root_containers: stack.Stack(*Container, 48) = .{},

    scroll_target: ?*Container = null,
    hover_root: ?*Container = null,
    next_hover_root: ?*Container = null,

    container_stack: stack.Stack(*Container, 32) = .{},

    pub inline fn begin(self: *ContainerManager) void {
        self.root_containers.clear();
        self.scroll_target = null;
        self.hover_root = self.next_hover_root;
        self.next_hover_root = null;
    }

    pub fn getOrAlloc(self: *ContainerManager, id: Id, opt: i32, frame: i32) ?*Container {
        if (self.containers.get(id)) |item| {
            const cnt = &item.data;
            if (cnt.open != 0 or (opt & Opt.CLOSED) == 0) {
                item.refresh(frame);
            }
            return cnt;
        }
        if (opt & Opt.CLOSED != 0) {
            return null;
        }

        const item = self.containers.alloc();
        item.* = .init(id, .{ .open = 1 }, frame);
        const cnt = &item.data;
        self.bringToFront(cnt);
        return cnt;
    }

    pub inline fn push(self: *ContainerManager, cnt: *Container) void {
        self.container_stack.push(cnt);
    }

    pub inline fn pushRoot(self: *ContainerManager, cnt: *Container) void {
        self.push(cnt);
        self.root_containers.push(cnt);
    }

    pub inline fn getCurrent(self: *ContainerManager) *Container {
        return self.container_stack.top();
    }

    pub inline fn pop(self: *ContainerManager) *Container {
        return self.container_stack.pop();
    }

    pub inline fn bringToFront(self: *ContainerManager, cnt: *Container) void {
        self.last_zindex += 1;
        cnt.zindex = self.last_zindex;
    }

    pub inline fn isHoverRoot(self: *const ContainerManager, cnt: ?*Container) bool {
        return self.hover_root == cnt;
    }

    pub inline fn setScrollTarget(self: *ContainerManager, cnt: *Container) void {
        self.scroll_target = cnt;
    }

    pub fn updateScroll(self: *ContainerManager, scroll_delta: math.Vec2) void {
        const st = self.scroll_target orelse return;
        st.scroll.x += scroll_delta.x;
        st.scroll.y += scroll_delta.y;
    }

    pub fn setPopup(self: *ContainerManager, cnt: *Container) void {
        self.hover_root = cnt;
        self.next_hover_root = cnt;
    }

    pub fn setNextHoverRoot(self: *ContainerManager, cnt: *Container) void {
        if (self.next_hover_root) |cur| {
            if (cnt.zindex <= cur.zindex) return;
        }
        self.next_hover_root = cnt;
    }

    pub fn bringHoverRootToFront(self: *ContainerManager) void {
        const cnt = self.next_hover_root orelse return;
        if (cnt.zindex >= 0 and cnt.zindex < self.last_zindex) {
            self.bringToFront(cnt);
        }
    }

    pub fn isActiveContainer(self: *ContainerManager) bool {
        const hover_root = self.hover_root orelse return false;
        const items = self.container_stack.slice();
        var i = items.len;
        while (i > 0) {
            i -= 1;
            const cnt = items[i];
            if (cnt == hover_root) {
                return true;
            }
            if (cnt.isRoot()) {
                break;
            }
        }
        return false;
    }

    pub fn updateRender(self: *ContainerManager, command_head: *command.Command) void {
        const roots = self.root_containers.slice();
        if (roots.len == 0) {
            return;
        }
        std.mem.sort(*Container, roots, {}, compareContainersByZIndex);

        for (roots) |cnt| {
            if (cnt.head != null and cnt.tail != null) {
                cnt.head.?.jump.dst = cnt.tail.?.base.next;
            }
        }

        command_head.jump.dst = roots[0].head.?.base.next;
        for (roots[0 .. roots.len - 1], roots[1..]) |prev, next| {
            if (prev.tail != null and next.head != null) {
                prev.tail.?.jump.dst = next.head.?.base.next;
            }
        }
        if (roots[roots.len - 1].tail) |last_tail| {
            last_tail.jump.dst = null;
        }
    }
};
