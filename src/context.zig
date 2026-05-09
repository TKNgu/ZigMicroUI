const std = @import("std");
const microui = @import("sdl.zig").microui;
const defaultStype = @import("style.zig").defaultStype;

fn push(stk: anytype, val: anytype) void {
    std.debug.assert(stk.*.idx < stk.*.items.len);
    var items = &stk.*.items;
    var index: usize = @intCast(stk.*.idx);
    items[index] = val;
    index += 1;
    stk.*.idx = @intCast(index);
}

fn get(stk: anytype) @TypeOf(stk.*.items[0]) {
    std.debug.assert(stk.*.idx < stk.*.items.len);
    const items = &stk.*.items;
    const index: usize = @intCast(stk.*.idx - 1);
    return items[index];
}

fn getPointer(stk: anytype) @TypeOf(&stk.*.items[0]) {
    std.debug.assert(stk.*.idx < stk.*.items.len);
    const items = &stk.*.items;
    const index: usize = @intCast(stk.*.idx - 1);
    return &items[index];
}

pub const Context = struct {
    const TextWidth = fn (data: ?*anyopaque, str: [*c]const u8, len: c_int) callconv(.c) c_int;
    const TextHeight = fn (data: ?*anyopaque) callconv(.c) c_int;
    const DrawFrame = fn (ctx: [*c]microui.mu_Context, rect: microui.mu_Rect, colorId: c_int) callconv(.c) void;

    ctx: microui.mu_Context,

    pub fn init(textWidth: TextWidth, textHeight: TextHeight, drawFrame: DrawFrame) Context {
        var ctx: Context = undefined;
        ctx.ctx = std.mem.zeroes(microui.mu_Context);
        ctx.ctx.draw_frame = drawFrame;
        ctx.ctx._style = defaultStype;
        ctx.ctx.style = &ctx.ctx._style;
        ctx.ctx.text_width = textWidth;
        ctx.ctx.text_height = textHeight;
        return ctx;
    }

    pub fn inputMouseMove(self: *Context, x: i32, y: i32) void {
        microui.mu_input_mousemove(&self.ctx, x, y);
    }

    pub fn inputMouseDown(self: *Context, x: i32, y: i32, btn: i32) void {
        microui.mu_input_mousedown(&self.ctx, x, y, btn);
    }

    pub fn inputMouseUp(self: *Context, x: i32, y: i32, btn: i32) void {
        microui.mu_input_mouseup(&self.ctx, x, y, btn);
    }

    pub fn nextCommand(self: *Context, cmd: [*c][*c]microui.mu_Command) bool {
        return microui.mu_next_command(&self.ctx, cmd) != 0;
    }

    pub fn begin(self: *Context) void {
        const ctx: *microui.mu_Context = @ptrCast(&self.ctx);
        ctx.*.command_list.idx = 0;
        ctx.*.root_list.idx = 0;
        ctx.*.scroll_target = null;
        ctx.*.hover_root = ctx.*.next_hover_root;
        ctx.*.next_hover_root = null;
        ctx.*.mouse_delta.x = ctx.*.mouse_pos.x - ctx.*.last_mouse_pos.x;
        ctx.*.mouse_delta.y = ctx.*.mouse_pos.y - ctx.*.last_mouse_pos.y;
        ctx.*.frame += 1;
    }

    pub fn end(self: *Context) void {
        const ctx: *microui.mu_Context = @ptrCast(&self.ctx);
        std.debug.assert(ctx.*.container_stack.idx == 0);
        std.debug.assert(ctx.*.clip_stack.idx == 0);
        std.debug.assert(ctx.*.id_stack.idx == 0);
        std.debug.assert(ctx.*.layout_stack.idx == 0);
        std.debug.assert(ctx.*.root_list.idx > 0);

        if (ctx.*.scroll_target != null) {
            ctx.*.scroll_target.*.scroll.x += ctx.*.scroll_delta.x;
            ctx.*.scroll_target.*.scroll.y += ctx.*.scroll_delta.y;
        }

        if (ctx.*.updated_focus == 0) {
            ctx.*.focus = 0;
        }
        ctx.*.updated_focus = 0;

        if (ctx.*.mouse_pressed != 0 and
            ctx.*.next_hover_root != 0 and
            ctx.*.next_hover_root.*.zindex < ctx.*.last_zindex and
            ctx.*.next_hover_root.*.zindex >= 0)
        {
            ctx.*.last_zindex += 1;
            ctx.*.next_hover_root.*.zindex = ctx.*.last_zindex;
        }

        ctx.*.key_pressed = 0;
        ctx.*.input_text[0] = '0';
        ctx.*.mouse_pressed = 0;
        ctx.*.scroll_delta = .{ .x = 0, .y = 0 };
        ctx.*.last_mouse_pos = ctx.*.mouse_pos;

        const size: usize = @intCast(ctx.*.root_list.idx);
        const array = ctx.*.root_list.items[0..size];
        std.sort.pdq([*c]microui.mu_Container, array, {}, struct {
            pub fn lessThanZIndex(
                _: void,
                a: [*c]microui.mu_Container,
                b: [*c]microui.mu_Container,
            ) bool {
                return a[0].zindex < b[0].zindex;
            }
        }.lessThanZIndex);

        for (array, 0..) |container, index| {
            if (index == 0) {
                const container_command_ptr: [*]c_char =
                    @ptrCast(@alignCast(&ctx.*.command_list.items));
                const container_command_draw_ptr: [*]c_char =
                    container_command_ptr + @sizeOf(microui.mu_JumpCommand);
                const cmd: [*c]microui.mu_Command =
                    @ptrCast(@alignCast(&ctx.*.command_list.items));
                cmd.*.jump.dst = container_command_draw_ptr;
            } else {
                const prev_container = array[index - 1];
                prev_container.*.tail.*.jump.dst = container.*.head + 1;
            }
            if (index == size - 1) {
                const raw_ptr: [*]c_char = @ptrCast(&ctx.*.command_list.items);
                const end_ptr = raw_ptr + @as(usize, @intCast(ctx.*.command_list.idx));
                container.*.tail.*.jump.dst = end_ptr;
            }
        }
    }

    pub fn hash(hashValue: *u32, data: [:0]const u8) void {
        for (data) |chr| {
            hashValue.* = (hashValue.* ^ chr) *% 16777619;
        }
    }

    pub fn getId(self: *Context, data: [:0]const u8) u32 {
        const ctx_ptr: *microui.mu_Context = @ptrCast(&self.ctx);
        const idx = ctx_ptr.id_stack.idx;
        var res = if (idx > 0) Res: {
            const id: u32 = @intCast(idx - 1);
            break :Res ctx_ptr.id_stack.items[id];
        } else 2166136261;
        hash(&res, data);
        ctx_ptr.*.last_id = @as(c_uint, @intCast(res));
        return res;
    }

    pub fn pushId(self: *Context, id: u32) void {
        push(&self.ctx.id_stack, id);
    }

    fn poolGet(_: *Context, items: [*c]microui.mu_PoolItem, len: usize, id: microui.mu_Id) i32 {
        for (0..len) |index| {
            if (items[index].id == id) {
                return @intCast(index);
            }
        }
        return -1;
    }

    fn poolUpdate(self: *Context, items: [*c]microui.mu_PoolItem, idx: usize) void {
        items[idx].last_update = self.ctx.frame;
    }

    fn poolInit(self: *Context, items: [*c]microui.mu_PoolItem, len: usize, id: microui.mu_Id) i32 {
        var frame = self.ctx.frame;
        var index_last: usize = undefined;
        for (0..len) |index| {
            if (items[index].last_update < frame) {
                frame = items[index].last_update;
                index_last = index;
            }
        }
        std.debug.assert(index_last > -1);
        items[index_last].id = id;
        self.poolUpdate(items, index_last);
        return @intCast(index_last);
    }

    fn bringToFront(self: *Context, cnt: [*c]microui.mu_Container) void {
        const ctx_ptr: *microui.mu_Context = &self.ctx;
        ctx_ptr.*.last_zindex += 1;
        cnt.*.zindex = ctx_ptr.last_zindex;
    }

    pub fn getContainer(self: *Context, id: microui.mu_Id, opt: c_int) [*c]microui.mu_Container {
        const ctx_ptr: *microui.mu_Context = @ptrCast(&self.ctx);
        var idx = self.poolGet(&ctx_ptr.*.container_pool, microui.MU_CONTAINERPOOL_SIZE, id);
        if (idx >= 0) {
            const index: usize = @intCast(idx);
            if (ctx_ptr.*.containers[index].open != 0 or (~opt & microui.MU_OPT_CLOSED) != 0) {
                const tmp_id: usize = @intCast(idx);
                self.poolUpdate(&ctx_ptr.*.container_pool, tmp_id);
            }
            return &ctx_ptr.*.containers[index];
        }
        if ((opt & microui.MU_OPT_CLOSED) != 0) {
            return null;
        }
        idx = self.poolInit(&ctx_ptr.container_pool, microui.MU_CONTAINERPOOL_SIZE, id);
        const index: usize = @intCast(idx);
        var cnt = &ctx_ptr.*.containers[index];
        cnt.* = std.mem.zeroes(microui.mu_Container);
        cnt.open = 1;
        self.bringToFront(cnt);
        return cnt;
    }

    pub fn getCurrentContainer(self: *Context) [*c]microui.mu_Container {
        return get(&self.ctx.container_stack);
    }

    pub fn layoutRow(self: *Context, items: c_int, widths: [*c]const c_int, height: c_int) void {
        const layout: [*c]microui.mu_Layout = getPointer(&self.ctx.layout_stack);
        const layout_size: usize = @intCast(layout.*.items);
        if (widths != null) {
            std.debug.assert(items <= microui.MU_MAX_WIDTHS);
            @memcpy(layout.*.widths[0..layout_size], widths);
        }
        layout.*.items = items;
        layout.*.position = microui.mu_vec2(layout.*.indent, layout.*.next_row);
        layout.*.size.y = height;
        layout.*.item_index = 0;
    }

    pub fn pushCommand(self: *Context, cmd_type: u8, cmd_size: usize) [*c]microui.mu_Command {
        const ctx: [*c]microui.mu_Context = @ptrCast(&self.ctx);
        return microui.mu_push_command(ctx, cmd_type, @intCast(cmd_size));
    }

    pub fn rectOverlapsVec2(r: microui.mu_Rect, p: microui.mu_Vec2) bool {
        return p.x >= r.x and p.x < r.x + r.w and p.y >= r.y and p.y < r.y + r.h;
    }

    pub fn pushContainer(self: *Context, cnt: [*c]microui.mu_Container) void {
        push(&self.ctx.container_stack, cnt);
    }

    pub fn pushRoot(self: *Context, cnt: [*c]microui.mu_Container) void {
        push(&self.ctx.root_list, cnt);
    }

    pub fn pushClipRectRoot(self: *Context) void {
        const unclipped_rect = microui.mu_Rect{
            .x = 0,
            .y = 0,
            .w = 0x1000000,
            .h = 0x1000000,
        };
        push(&self.ctx.clip_stack, unclipped_rect);
    }

    pub fn pushJump(
        self: *Context,
        dst: [*c]const microui.mu_JumpCommand,
    ) [*c]microui.mu_JumpCommand {
        const cmd = self.pushCommand(microui.MU_COMMAND_JUMP, @sizeOf(microui.mu_JumpCommand));
        cmd.?.*.jump.dst = @constCast(dst);
        return @ptrCast(cmd);
    }

    pub fn beginRootContainer(self: *Context, cnt: [*c]microui.mu_Container) void {
        self.pushContainer(cnt);
        self.pushRoot(cnt);
        cnt.*.head = @ptrCast(self.pushJump(null));
        if (rectOverlapsVec2(cnt.*.rect, self.ctx.mouse_pos) and
            (self.ctx.hover_root == null or cnt.*.zindex > self.ctx.hover_root.*.zindex))
        {
            self.ctx.hover_root = cnt;
        }
        self.pushClipRectRoot();
    }
};
