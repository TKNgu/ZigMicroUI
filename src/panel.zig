const Context = @import("context.zig").Context;
const ui = @import("ui.zig");
const microui = @import("sdl.zig").microui;

pub const Panel = struct {
    pub fn beginPanelEx(context: *Context, name: [:0]const u8, opt: c_int) void {
        const id = context.getId(name);
        const ctx = &context.ctx;
        context.pushId(id);
        const container = context.getContainer(ctx.*.last_id, opt);
        container.*.rect = ui.layoutNex(ctx);
        if ((~opt & microui.MU_OPT_NOFRAME) != 0) {
            ui.drawFrame(ctx, container.*.rect, microui.MU_COLOR_PANELBG);
        }
        ui.pushContainer(ctx, container);
        ui.pushContainerBody(ctx, container, container.*.rect, opt);
        ui.pushClipRect(ctx, container.*.body);
    }

    pub fn beginPanel(context: *Context, name: [:0]const u8) void {
        beginPanelEx(context, name, 0);
    }

    pub fn endPanel(context: *Context) void {
        const ctx = &context.ctx;
        microui.mu_pop_clip_rect(ctx);
        microui.pop_container(ctx);
    }
};
