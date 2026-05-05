const std = @import("std");
const microui = @import("sdl.zig").microui;
const defaultStype = @import("style.zig").defaultStype;

fn push(stk: anytype, val: anytype) void {
    std.debug.assert(stk.*.idx < stk.*.items.len);
    const index: usize = @intCast(stk.*.idx);
    var items = stk.*.items;
    items[index] = val;
    stk.*.idx += 1;
}

pub fn intersectRects(r1: microui.mu_Rect, r2: microui.mu_Rect) microui.mu_Rect {
    const x1 = @max(r1.x, r2.x);
    const y1 = @max(r1.y, r2.y);
    var x2 = @min(r1.x + r1.w, r2.x + r2.w);
    var y2 = @min(r1.y + r1.h, r2.y + r2.h);
    if (x2 < x1) {
        x2 = x1;
    }
    if (y2 < y1) {
        y2 = y1;
    }
    return .{ .x = x1, .y = y1, .w = x2 - x1, .h = y2 - y1 };
}

pub fn getClipRect(ctx: [*c]microui.mu_Context) microui.mu_Rect {
    const idx = ctx.*.clip_stack.idx;
    std.debug.assert(idx > 0);
    const id = idx - 1;
    const last: usize = @intCast(id);
    const context: *microui.mu_Context = @ptrCast(ctx);
    return context.*.clip_stack.items[last];
}

pub fn drawRect(ctx: [*c]microui.mu_Context, rect: microui.mu_Rect, color: microui.mu_Color) callconv(.c) void {
    var cmd: *microui.mu_Command = undefined;
    const clipRect = intersectRects(rect, getClipRect(ctx));
    if (clipRect.w > 0 and clipRect.h > 0) {
        cmd = microui.mu_push_command(
            ctx,
            microui.MU_COMMAND_RECT,
            @sizeOf(microui.mu_RectCommand),
        );
        cmd.*.rect.rect = clipRect;
        cmd.*.rect.color = color;
    }
}

pub fn drawFrame(ctx: [*c]microui.mu_Context, rect: microui.mu_Rect, colorId: c_int) callconv(.c) void {
    if (colorId < 0) {
        std.debug.panic("Color ID must be >= 0", .{});
    }
    const id: usize = @intCast(colorId);
    const stype: *microui.mu_Style = @ptrCast(ctx.*.style);
    const color = stype.*.colors[id];
    drawRect(ctx, rect, color);
    if (colorId == microui.MU_COLOR_SCROLLBASE or
        colorId == microui.MU_COLOR_SCROLLTHUMB or
        colorId == microui.MU_COLOR_TITLEBG)
    {
        return;
    }

    const style: *microui.mu_Style = @ptrCast(ctx.*.style);
    if (style.*.colors[microui.MU_COLOR_BORDER].a != 0) {
        microui.mu_draw_box(
            ctx,
            .{ .x = rect.x - 1, .y = rect.y - 1, .w = rect.w + 2, .h = rect.h + 2 },
            style.*.colors[microui.MU_COLOR_BORDER],
        );
    }
}

pub const Context = struct {
    const TextWidth = fn (data: ?*anyopaque, str: [*c]const u8, len: c_int) callconv(.c) c_int;
    const TextHeight = fn (data: ?*anyopaque) callconv(.c) c_int;

    ctx: microui.mu_Context,

    pub fn init(textWidth: TextWidth, textHeight: TextHeight) Context {
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

    pub fn getContainer2(self: *Context, id: microui.mu_Id, opt: c_int) [*c]microui.mu_Container {
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
        const ctx: *microui.mu_Context = @ptrCast(&self.ctx);
        const context: [*c]microui.mu_Context = @ptrCast(ctx);
        std.debug.assert(context.*.container_stack.idx > 0);
        const items: [32][*c]microui.mu_Container = context.*.container_stack.items;
        const index: usize = @intCast(context.*.container_stack.idx - 1);
        return items[index];
    }

    pub fn getLayout(self: *Context) [*c]microui.mu_Layout {
        const ctx: [*c]microui.mu_Context = @ptrCast(&self.ctx);
        const context: [*c]microui.mu_Context = @ptrCast(ctx);
        std.debug.assert(context.*.layout_stack.idx < context.*.layout_stack.items.len);
        var items = context.*.layout_stack.items;
        const index: usize = @intCast(context.*.layout_stack.idx - 1);
        return &items[index];
    }

    pub fn layoutRow(self: *Context, items: c_int, widths: [*c]const c_int, height: c_int) void {
        const layout: [*c]microui.mu_Layout = self.getLayout();
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
};
