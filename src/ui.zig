const std = @import("std");
const microui = @import("sdl.zig").microui;
const draw = @import("draw.zig");

const defaultStype: microui.mu_Style = .{
    .font = null,
    .size = .{ .x = 68, .y = 10 },
    .padding = 5,
    .spacing = 4,
    .indent = 24,
    .title_height = 24,
    .scrollbar_size = 12,
    .thumb_size = 8,
    .colors = .{
        .{ .r = 230, .g = 230, .b = 230, .a = 255 },
        .{ .r = 25, .g = 25, .b = 25, .a = 255 },
        .{ .r = 50, .g = 50, .b = 50, .a = 255 },
        .{ .r = 25, .g = 25, .b = 25, .a = 255 },
        .{ .r = 240, .g = 240, .b = 240, .a = 255 },
        .{ .r = 0, .g = 0, .b = 0, .a = 0 },
        .{ .r = 75, .g = 75, .b = 75, .a = 255 },
        .{ .r = 95, .g = 95, .b = 95, .a = 255 },
        .{ .r = 115, .g = 115, .b = 115, .a = 255 },
        .{ .r = 30, .g = 30, .b = 30, .a = 255 },
        .{ .r = 35, .g = 35, .b = 35, .a = 255 },
        .{ .r = 40, .g = 40, .b = 40, .a = 255 },
        .{ .r = 43, .g = 43, .b = 43, .a = 255 },
        .{ .r = 30, .g = 30, .b = 30, .a = 255 },
    },
};

pub fn muRect(x: i32, y: i32, w: i32, h: i32) microui.mu_Rect {
    return .{
        .x = x,
        .y = y,
        .w = w,
        .h = h,
    };
}

fn expandRect(rect: microui.mu_Rect, n: i32) microui.mu_Rect {
    return muRect(rect.x - n, rect.y - n, rect.w + n * 2, rect.h + n * 2);
}

fn intersectRects(r1: microui.mu_Rect, r2: microui.mu_Rect) microui.mu_Rect {
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
    return muRect(x1, y1, x2 - x1, y2 - y1);
}

fn getClipRect(ctx: [*c]microui.mu_Context) microui.mu_Rect {
    const idx = ctx.*.clip_stack.idx;
    std.debug.assert(idx > 0);
    const id = idx - 1;
    const last: usize = @intCast(id);
    return ctx.*.clip_stack.items[last];
}

fn drawRect(ctx: [*c]microui.mu_Context, rect: microui.mu_Rect, color: microui.mu_Color) callconv(.c) void {
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

fn drawFrame(ctx: [*c]microui.mu_Context, rect: microui.mu_Rect, colorId: c_int) callconv(.c) void {
    if (colorId < 0) {
        std.debug.panic("Color ID must be >= 0", .{});
    }
    const id: usize = @intCast(colorId);
    drawRect(ctx, rect, ctx.*.style.*.colors[id]);
    if (colorId == microui.MU_COLOR_SCROLLBASE or
        colorId == microui.MU_COLOR_SCROLLTHUMB or
        colorId == microui.MU_COLOR_TITLEBG)
    {
        return;
    }

    if (ctx.*.style.*.colors[microui.MU_COLOR_BORDER].a != 0) {
        microui.mu_draw_box(
            ctx,
            expandRect(rect, 1),
            ctx.*.style.*.colors[microui.MU_COLOR_BORDER],
        );
    }
}

pub fn muInit(ctx: *microui.mu_Context) void {
    ctx.* = std.mem.zeroes(microui.mu_Context);
    ctx.*.draw_frame = drawFrame;
    ctx.*._style = defaultStype;
    ctx.*.style = &ctx.*._style;
}

pub fn begin(ctx: [*c]microui.mu_Context) void {
    std.debug.assert(ctx.*.text_width != null);
    std.debug.assert(ctx.*.text_height != null);
    ctx.*.command_list.idx = 0;
    ctx.*.root_list.idx = 0;
    ctx.*.scroll_target = null;
    ctx.*.hover_root = ctx.*.next_hover_root;
    ctx.*.next_hover_root = null;
    ctx.*.mouse_delta.x = ctx.*.mouse_pos.x - ctx.*.last_mouse_pos.x;
    ctx.*.mouse_delta.y = ctx.*.mouse_pos.y - ctx.*.last_mouse_pos.y;
    ctx.*.frame += 1;
}

fn push(stk: anytype, val: anytype) void {
    std.debug.assert(stk.idx < std.mem.len(stk.items));
    stk.*.items[@as(usize, @intCast(stk.idx))] = val;
    stk.*.idx += 1;
}

const HASH_INITIAL: usize = 2166136261;

fn hash(hashValue: *usize, data: [*c]const u8, size: usize) void {
    const prime: usize = 16777619;
    var i: usize = 0;
    while (i < size) : (i += 1) {
        hashValue.* = hashValue.* * prime + @as(usize, @intCast(data[i]));
    }
}

fn getId(ctx: [*c]microui.mu_Context, data: [*c]const u8, size: usize) microui.mu_Id {
    const idx = ctx.*.id_stack.idx;
    var res = if (idx > 0) Res: {
        const id: usize = @intCast(idx - 1);
        break :Res ctx.*.id_stack.items[id];
    } else HASH_INITIAL;
    hash(&res, data, size);
    ctx.*.last_id = @as(c_uint, @intCast(res));
    return @intCast(res);
}

fn getContainer(ctx: [*c]microui.mu_Context, id: microui.mu_Id, opt: c_int) [*c]microui.mu_Container {
    var idx = microui.mu_pool_get(ctx, ctx.*.container_pool, microui.MU_CONTAINERPOOL_SIZE, id);
    if (idx >= 0) {
        if (ctx.*.containers[idx].open or ~opt & microui.MU_OPT_CLOSED) {
            microui.mu_pool_update(ctx, ctx.*.container_pool, idx);
        }
        return &ctx.*.containers[idx];
    }
    if (opt & microui.MU_OPT_CLOSED) {
        return null;
    }
    idx = microui.pool_init(ctx, ctx.*.container_pool, microui.MU_CONTAINERPOOL_SIZE, id);
    var cnt = &ctx.*.containers[idx];
    std.mem.setzero(microui.mu_Container, cnt);
    cnt.open = 1;
    microui.mu_bring_to_front(ctx, cnt);
    return cnt;
}

pub fn pushJump(ctx: [*c]microui.mu_Context, dst: [*c]const microui.mu_Command) [*c]microui.mu_JumpCommand {
    const cmd = push(ctx.*.command_list, microui.mu_push_command(ctx, microui.MU_COMMAND_JUMP, microui.MU_COMMANDLIST_SIZE));
    cmd.?.*.jump.dst = dst;
    return cmd.?.*.jump;
}

pub fn beginRootContainer(ctx: [*c]microui.mu_Context, cnt: [*c]microui.mu_Container) void {
    push(ctx.*.container_stack, cnt);
    push(ctx.*.root_list, cnt);
    cnt.head = pushJump(ctx, null);
    cnt.head.?.*.jump.dst = ctx.*.command_list.items + ctx.*.command_list.idx;
    ctx.*.command_list.idx += 1;
}

pub fn beginWindow(
    ctx: [*c]microui.mu_Context,
    title: [*c]const u8,
    windowRect: microui.mu_Rect,
    opt: c_int,
) c_int {
    const windowId = getId(ctx, title, std.mem.len(title));
    const container = getContainer(ctx, windowId, opt);
    if (container == null or container.?.*.open == 0) {
        return 0;
    }
    push(ctx.*.id_stack, windowId);

    if (container.?.*.rect.w == 0) {
        container.?.*.rect = windowRect;
    }
    beginRootContainer(ctx, container.?);
    const rect = container.?.*.rect;
    var body = rect;
    if ((~opt & microui.MU_OPT_NOTITLE) != 0) {
        drawFrame(ctx, rect, microui.MU_COLOR_WINDOWBG);
    }

    if ((~opt & microui.MU_OPT_NOTITLE) != 0) {
        var titleRect = rect;
        titleRect.h = draw.textHeight(ctx.*.style.*.font);
        drawFrame(ctx, titleRect, microui.MU_COLOR_TITLEBG);

        if ((~opt & microui.MU_OPT_NOTITLE) != 0) {
            const titleId = getId(ctx, "!title", 6);
            microui.mu_update_control(ctx, titleId, titleRect, opt);
            microui.mu_draw_control_text(ctx, title, titleRect, microui.MU_COLOR_TITLETEXT, opt);
            if (titleId == ctx.*.focus and ctx.*.mouse_down == microui.MU_MOUSE_LEFT) {
                container.*.rect.x += ctx.*.mouse_delta.x;
                container.*.rect.y += ctx.*.mouse_delta.y;
            }
            body.y += titleRect.h;
            body.h -= titleRect.h;
        }

        if ((~opt & microui.MU_OPT_NOCLOSE) != 0) {
            const closeId = getId(ctx, "!close", 6);
            const closeRect = muRect(
                titleRect.x + titleRect.w - titleRect.w,
                titleRect.y,
                titleRect.h,
                titleRect.h,
            );
            titleRect.w -= closeRect.w;
            microui.mu_draw_icon(
                ctx,
                @as(c_int, @intCast(closeId)),
                closeRect,
                ctx.*.style.*.colors[microui.MU_COLOR_TITLETEXT],
            );
            microui.mu_update_control(ctx, closeId, closeRect, opt);
            if (ctx.*.mouse_pressed == microui.MU_MOUSE_LEFT and closeId == ctx.*.focus) {
                container.*.open = 0;
            }
        }
    }
    microui.push_container_body(ctx, container, body, opt);
}
