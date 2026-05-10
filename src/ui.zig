const std = @import("std");
const microui = @import("sdl.zig").microui;
const drctxaw = @import("draw.zig");
const Context = @import("context.zig").Context;
const Rect = @import("rect.zig").Rect;

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

pub fn rectOverlapsVec2(r: microui.mu_Rect, p: microui.mu_Vec2) bool {
    return p.x >= r.x and p.x < r.x + r.w and p.y >= r.y and p.y < r.y + r.h;
}

// Context

pub fn drawControlText(
    ctx: [*c]microui.mu_Context,
    str: [*c]const u8,
    rect: microui.mu_Rect,
    colorid: c_int,
    opt: c_int,
) void {
    const font = ctx.*.style.*.font;
    // TODO: fix this
    // const tw = ctx.*.text_width(font, str, -1);
    const tw = 0;

    pushClipRect(ctx, rect);
    var pos: microui.mu_Vec2 = undefined;
    const th = 0;
    // TODO: fix this
    // pos.y = rect.y + (rect.h - ctx.*.text_height) / 2;
    pos.y = rect.y + @divFloor(rect.h - th, 2);
    if ((opt & microui.MU_OPT_ALIGNCENTER) != 0) {
        pos.x = rect.x + @divFloor(rect.w - tw, 2);
    } else if ((opt & microui.MU_OPT_ALIGNRIGHT) != 0) {
        pos.x = rect.x + rect.w - tw - ctx.*.style.*.padding;
    } else {
        pos.x = rect.x + ctx.*.style.*.padding;
    }
    const index: usize = @intCast(colorid);
    const context: [*c]microui.mu_Context = @ptrCast(ctx);
    const stype: *microui.mu_Style = @ptrCast(context.*.style);
    const color = stype.*.colors[index];
    microui.mu_draw_text(ctx, font, str, -1, pos, color);
    popClipRect(ctx);
}

pub fn drawIcon(
    ctx: [*c]microui.mu_Context,
    id: microui.mu_Id,
    rect: microui.mu_Rect,
    color: microui.mu_Color,
) void {
    const clipped = microui.mu_check_clip(ctx, rect);
    if (clipped == microui.MU_CLIP_ALL) {
        return;
    }
    if (clipped == microui.MU_CLIP_PART) {
        microui.mu_set_clip(ctx, microui.mu_get_clip_rect(ctx));
    }

    const cmd = microui.mu_push_command(
        ctx,
        microui.MU_COMMAND_ICON,
        @sizeOf(microui.mu_IconCommand),
    );
    cmd.*.icon.id = @bitCast(@as(c_uint, @truncate(id)));
    cmd.*.icon.rect = rect;
    cmd.*.icon.color = color;

    if (clipped != 0) {
        pushClipRectRoot(ctx);
    }
}

pub fn updateControl(
    ctx: [*c]microui.mu_Context,
    id: microui.mu_Id,
    rect: microui.mu_Rect,
    opt: c_int,
) void {
    const mouse_over = microui.mu_mouse_over(ctx, rect);
    if (ctx.*.focus == id) {
        ctx.*.updated_focus = 1;
    }
    if (opt & microui.MU_OPT_NOINTERACT != 0) {
        return;
    }
    if (mouse_over != 0 and ctx.*.mouse_down == 0) {
        ctx.*.hover = id;
    }
    if (ctx.*.focus == id) {
        if (ctx.*.mouse_pressed != 0 and mouse_over == 0) {
            microui.mu_set_focus(ctx, 0);
        }
        if (ctx.*.mouse_down == 0 and ~opt & microui.MU_OPT_HOLDFOCUS != 0) {
            microui.mu_set_focus(ctx, 0);
        }
    }
    if (ctx.*.hover == id) {
        if (ctx.*.mouse_pressed != 0) {
            microui.mu_set_focus(ctx, id);
        } else if (mouse_over == 0) {
            ctx.*.hover = 0;
        }
    }
}

fn expandRect(rect: microui.mu_Rect, n: i32) microui.mu_Rect {
    return .{ .x = rect.x - n, .y = rect.y - n, .w = rect.w + n * 2, .h = rect.h + n * 2 };
}

pub fn pushCommand(
    ctx: [*c]microui.mu_Context,
    cmd_type: u8,
    cmd_size: usize,
) [*c]microui.mu_Command {
    return microui.mu_push_command(ctx, cmd_type, @intCast(cmd_size));
}

pub fn pushJump(
    ctx: [*c]microui.mu_Context,
    dst: [*c]const microui.mu_JumpCommand,
) [*c]microui.mu_JumpCommand {
    const cmd = pushCommand(ctx, microui.MU_COMMAND_JUMP, @sizeOf(microui.mu_JumpCommand));
    cmd.?.*.jump.dst = @constCast(dst);
    const result: [*c]microui.mu_JumpCommand = @ptrCast(cmd);
    return result;
}

pub fn pushRoot(ctx: [*c]microui.mu_Context, cnt: [*c]microui.mu_Container) void {
    const ctx_ptr: *microui.mu_Context = @ptrCast(ctx);
    var root_list = &ctx_ptr.*.root_list.items;
    var index: usize = @intCast(ctx_ptr.*.root_list.idx);

    root_list[index] = cnt;
    index += 1;
    ctx_ptr.*.root_list.idx = @intCast(index);
}

pub fn pushClipRectRoot(ctx: [*c]microui.mu_Context) void {
    const unclipped_rect = microui.mu_Rect{
        .x = 0,
        .y = 0,
        .w = 0x1000000,
        .h = 0x1000000,
    };
    const ctx_ptr: *microui.mu_Context = @ptrCast(ctx);
    var clip_stack = &ctx_ptr.*.clip_stack.items;
    var index: usize = @intCast(ctx_ptr.*.clip_stack.idx);
    clip_stack[index] = unclipped_rect;
    index += 1;
    ctx_ptr.*.clip_stack.idx = @intCast(index);
}

pub fn beginRootContainer(ctx: [*c]microui.mu_Context, cnt: [*c]microui.mu_Container) void {
    pushContainer(ctx, cnt);
    pushRoot(ctx, cnt);
    cnt.*.head = @ptrCast(pushJump(ctx, null));
    const context: [*c]microui.mu_Context = @ptrCast(ctx);
    if (rectOverlapsVec2(cnt.*.rect, context.*.mouse_pos)) {
        if (context.*.next_hover_root != null) {
            context.*.next_hover_root = cnt;
        } else {
            // TODO: this is a hack to make sure the hover root is always the
            // const next_hover_root: [*c]microui.mu_Container = context.*.next_hover_root;
            // if (cnt.*.zindex > next_hover_root.*.zindex) {
            //     context.*.next_hover_root = cnt;
            // }
        }
    }
    pushClipRectRoot(ctx);
}

pub fn endRootContainer(ctx: [*c]microui.mu_Context) void {
    const cnt = microui.mu_get_current_container(ctx);
    const jump_command = pushJump(ctx, null);
    cnt.*.tail = @ptrCast(jump_command);
    const raw_ptr: [*]c_char = @ptrCast(&ctx.*.command_list.items);
    const end_ptr = raw_ptr + @as(usize, @intCast(ctx.*.command_list.idx));
    cnt.*.head.*.jump.dst = end_ptr;
    microui.mu_pop_clip_rect(ctx);
    microui.pop_container(ctx);
}

pub fn setFocus(ctx: [*c]microui.mu_Context, id: microui.mu_Id) void {
    microui.mu_set_focus(ctx, id);
}

pub fn textBox(ctx: [*c]microui.mu_Context, buf: [*c]u8, bufsz: usize) c_int {
    const buffer_size: c_int = @intCast(bufsz);
    return microui.mu_textbox(ctx, buf, buffer_size);
}

pub fn pushContainer(ctx: [*c]microui.mu_Context, cnt: [*c]microui.mu_Container) void {
    const context: *microui.mu_Context = @ptrCast(ctx);
    std.debug.assert(context.*.container_stack.idx < context.*.container_stack.items.len);
    var items: [][*c]microui.mu_Container = &context.*.container_stack.items;
    const index: usize = @intCast(context.*.container_stack.idx);
    items[index] = cnt;
    ctx.*.container_stack.idx += 1;
}

pub fn getLayout(ctx: [*c]microui.mu_Context) [*c]microui.mu_Layout {
    const context: [*c]microui.mu_Context = @ptrCast(ctx);
    std.debug.assert(context.*.layout_stack.idx < context.*.layout_stack.items.len);
    var items = context.*.layout_stack.items;
    const index: usize = @intCast(context.*.layout_stack.idx - 1);
    return &items[index];
}

const LayoutType = enum(u8) { RELATIVE = 1, ABSOLUTE = 2 };

pub fn layoutNex(ctx: [*c]microui.mu_Context) microui.mu_Rect {
    const layout: [*c]microui.mu_Layout = getLayout(ctx);
    const style: [*c]microui.mu_Style = @ptrCast(ctx.*.style);

    var res: microui.mu_Rect = undefined;
    if (layout.*.next_type != 0) {
        // handle rect set by `mu_layout_set_next`
        const layout_type = layout.*.next_type;
        layout.*.next_type = 0;
        res = layout.*.next;
        std.debug.print("0 w {d} h {d}\n", .{ res.w, res.h });
        if (layout_type == @intFromEnum(LayoutType.ABSOLUTE)) {
            return res;
        }
    } else {
        // handle next row
        if (layout.*.item_index == layout.*.items) {
            microui.mu_layout_row(ctx, layout.*.items, null, layout.*.size.y);
        }

        // position
        res.x = layout.*.position.x;
        res.y = layout.*.position.y;

        // size
        const index: usize = @intCast(layout.*.item_index);
        const widths: [16]c_int = layout.*.widths;
        if (layout.*.items > 0) {
            res.w = widths[index];
        } else {
            res.w = layout.*.size.x;
        }
        res.h = layout.*.size.y;

        if (res.w == 0) {
            res.w = style.*.size.x + style.*.padding * 2;
        }
        if (res.h == 0) {
            res.h = style.*.size.y + style.*.padding * 2;
        }
        if (res.w < 0) {
            res.w += layout.*.body.w - res.x + 1;
        }
        if (res.h < 0) {
            res.h += layout.*.body.h - res.y + 1;
        }

        layout.*.item_index += 1;
    }
    layout.*.position.x += res.w + style.*.spacing;
    layout.*.next_row = microui.mu_max(layout.*.next_row, res.y + res.h + style.*.spacing);

    // apply body offset
    res.x += layout.*.body.x;
    res.y += layout.*.body.y;

    // update max position
    layout.*.max.x = microui.mu_max(layout.*.max.x, res.x + res.w);
    layout.*.max.y = microui.mu_max(layout.*.max.y, res.y + res.h);

    return res;
}

pub fn pushContainerBody(
    ctx: [*c]microui.mu_Context,
    cnt: [*c]microui.mu_Container,
    body: microui.mu_Rect,
    opt: c_int,
) void {
    var tmp_body = body;
    if ((~opt & microui.MU_OPT_NOSCROLL) != 0) {
        microui.scrollbars(ctx, cnt, &tmp_body);
    }
    microui.push_layout(ctx, expandRect(tmp_body, -ctx.*.style.*.padding), cnt.*.scroll);
    cnt.*.body = tmp_body;
}

pub fn getCurrentContainer(ctx: [*c]microui.mu_Context) [*c]microui.mu_Container {
    const context: [*c]microui.mu_Context = @ptrCast(ctx);
    std.debug.assert(context.*.container_stack.idx > 0);
    const items: [32][*c]microui.mu_Container = context.*.container_stack.items;
    const index: usize = @intCast(context.*.container_stack.idx - 1);
    return items[index];
}

pub fn layoutRow(ctx: [*c]microui.mu_Context, items: c_int, widths: [*c]const c_int, height: c_int) void {
    const layout: [*c]microui.mu_Layout = getLayout(ctx);
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

pub fn label(ctx: [*c]microui.mu_Context, text: [*c]const u8) void {
    microui.mu_draw_control_text(ctx, text, getLayout(ctx).*.body, microui.MU_COLOR_TEXT, 0);
}

fn push(stk: anytype, val: anytype) void {
    std.debug.assert(stk.*.idx < stk.*.items.len);
    const index: usize = @intCast(stk.*.idx);
    var items = stk.*.items;
    items[index] = val;
    stk.*.idx += 1;
}

fn pop(stk: anytype) void {
    var index: usize = @intCast(stk.*.idx);
    std.debug.assert(index > 0);
    index -= 1;
    stk.*.idx = @intCast(index);
}

pub fn popClipRect(ctx: [*c]microui.mu_Context) void {
    pop(&ctx.*.clip_stack);
}

pub fn pushClipRect(ctx: [*c]microui.mu_Context, rect: microui.mu_Rect) void {
    const last = getClipRect(ctx);
    push(&ctx.*.clip_stack, intersectRects(rect, last));
}
