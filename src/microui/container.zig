const std = @import("std");
const math = @import("math.zig");
const command = @import("command.zig");
const stack = @import("stack.zig");

const types = @import("types.zig");
const Id = types.Id;
const Opt = types.Opt;

const Pool = @import("pool.zig").Pool;

pub const Container = struct {
    head: ?*command.Command = null,
    tail: ?*command.Command = null,
    rect: math.Rect = .zero,
    body: math.Rect = .zero,
    content_size: math.Vec2 = .zero,
    scroll: math.Vec2 = .zero,
    zindex: i32 = 0,
    is_open: bool = false,

    pub inline fn isRoot(self: *const Container) bool {
        return self.head != null;
    }

    fn updateScroll(self: *Container, scroll_delta: math.Vec2) void {
        self.scroll.add(scroll_delta);
    }

    fn compareContainersByZIndex(_: void, a: *Container, b: *Container) bool {
        return a.zindex < b.zindex;
    }
};

pub const ContainerManager = struct {
    containers: Pool(Container, 48) = .{},
    container_stack: stack.Stack(*Container, 32) = .{},
    root_containers: stack.List(*Container, 48) = .{},
    scroll_target: ?*Container = null,
    hover_root: ?*Container = null,
    next_hover_root: ?*Container = null,
    last_zindex: i32 = 0,

    pub inline fn begin(self: *ContainerManager) void {
        self.root_containers.clear();
        self.scroll_target = null;
        self.hover_root = self.next_hover_root;
        self.next_hover_root = null;
    }

    pub fn getOrAlloc(self: *ContainerManager, id: Id, opt: i32, frame: i32) ?*Container {
        if (self.containers.get(id)) |item| {
            const cnt = &item.data;
            if (cnt.is_open or !Opt.has(opt, .closed)) {
                item.refresh(frame);
            }
            return cnt;
        }
        if (Opt.has(opt, .closed)) {
            return null;
        }

        const item = self.containers.allocAndInit(.{ .is_open = true }, id, frame);
        const cnt = &item.data;
        self.bringToFront(cnt);
        return cnt;
    }

    pub inline fn push(self: *ContainerManager, cnt: *Container) void {
        self.container_stack.push(cnt);
    }

    pub inline fn pushRoot(self: *ContainerManager, cnt: *Container) void {
        self.push(cnt);
        self.root_containers.append(cnt);
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
        const cnt = self.scroll_target orelse return;
        cnt.updateScroll(scroll_delta);
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
        var i = items.len - 1;
        while (i >= 0) : (i -= 1) {
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
        std.mem.sort(*Container, roots, {}, Container.compareContainersByZIndex);

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
