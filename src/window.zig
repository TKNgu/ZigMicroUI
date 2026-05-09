const std = @import("std");
const microui = @import("sdl.zig").microui;
const Context = @import("context.zig").Context;
const Rect = @import("rect.zig").Rect;
const ui = @import("ui.zig");

pub const Window = struct {
    pub fn begin(context: *Context, title: [:0]const u8, windowRect: Rect, opt: c_int) bool {
        const windowId: c_uint = @intCast(context.getId(title));
        context.pushId(windowId);

        const container = context.getContainer(windowId, opt);
        if (container == null or container.*.open == 0) {
            return false;
        }
        if (container.?.*.rect.w == 0) {
            container.?.*.rect = windowRect.getRect();
        }

        context.beginRootContainer(container.?);

        const ctx = &context.ctx;
        var body = container.*.rect;
        const rect = body;

        if ((~opt & microui.MU_OPT_NOFRAME) != 0) {
            ui.drawFrame(ctx, rect, microui.MU_COLOR_WINDOWBG);
        }

        if ((~opt & microui.MU_OPT_NOTITLE) != 0) {
            var title_rect = rect;
            title_rect.h = ctx.*.style.*.title_height;
            ui.drawFrame(ctx, title_rect, microui.MU_COLOR_TITLEBG);

            if ((~opt & microui.MU_OPT_NOTITLE) != 0) {
                const title_id = context.getId("!title");
                ui.drawControlText(ctx, title, title_rect, microui.MU_COLOR_TITLETEXT, opt);
                if (title_id == ctx.*.focus and ctx.*.mouse_down == microui.MU_MOUSE_LEFT) {
                    container.*.rect.x += ctx.*.mouse_delta.x;
                    container.*.rect.y += ctx.*.mouse_delta.y;
                }
                body.y += title_rect.h;
                body.h -= title_rect.h;
            }

            if ((~opt & microui.MU_OPT_NOCLOSE) != 0) {
                const close_id = context.getId("!close");
                const close_rect = microui.mu_Rect{
                    .x = title_rect.x + title_rect.w - title_rect.h,
                    .y = title_rect.y,
                    .w = title_rect.h,
                    .h = title_rect.h,
                };
                title_rect.w -= close_rect.w;
                const stype: *microui.mu_Style = @ptrCast(ctx.*.style);
                ui.drawIcon(
                    ctx,
                    microui.MU_ICON_CLOSE, // TODO: fix this
                    close_rect,
                    stype.*.colors[microui.MU_COLOR_TITLETEXT],
                );
                // microui.mu_update_control(ctx, close_id, close_rect, opt);
                ui.updateControl(ctx, close_id, close_rect, opt);
                if (ctx.*.mouse_pressed == microui.MU_MOUSE_LEFT and close_id == ctx.*.focus) {
                    container.*.open = 0;
                }
            }
        }

        microui.push_container_body(ctx, container.?, body, opt);

        if ((~opt & microui.MU_OPT_NORESIZE) != 0) {
            const size = ctx.*.style.*.title_height;
            const resize_id = microui.mu_get_id(ctx, "!resize", 7);
            const resize_rect = microui.mu_rect(
                rect.x + rect.w - size,
                rect.y + rect.h - size,
                size,
                size,
            );
            microui.mu_update_control(ctx, resize_id, resize_rect, opt);
            if (resize_id == ctx.*.focus and ctx.*.mouse_down == microui.MU_MOUSE_LEFT) {
                container.*.rect.w = microui.mu_max(96, container.*.rect.w + ctx.*.mouse_delta.x);
                container.*.rect.h = microui.mu_max(64, container.*.rect.h + ctx.*.mouse_delta.y);
            }
        }

        if ((~opt & microui.MU_OPT_NOSCROLL) != 0) {
            const auto_rect = microui.get_layout(ctx).*.body;
            container.*.scroll.y = microui.mu_max(container.*.scroll.y, auto_rect.y);
            container.*.scroll.y = microui.mu_min(
                container.*.scroll.y,
                auto_rect.y + auto_rect.h - container.*.content_size.y,
            );
        }

        if ((opt & microui.MU_OPT_POPUP) != 0 and ctx.*.mouse_pressed != 0 and ctx.*.hover_root != container) {
            container.*.open = 0;
        }

        microui.mu_push_clip_rect(ctx, rect);
        return microui.MU_RES_ACTIVE != 0;
    }

    pub fn end(context: *Context) void {
        const ctx = &context.ctx;
        ui.popClipRect(ctx);
        ui.endRootContainer(ctx);
    }
};
