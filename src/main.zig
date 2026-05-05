const std = @import("std");
const sdl = @import("sdl.zig").sdl;
const microui = @import("sdl.zig").microui;
const draw = @import("draw.zig");
const atlas = @import("sdl.zig").atlas;
const ui = @import("ui.zig");
const Context = @import("context.zig").Context;
const Rect = @import("rect.zig").Rect;

fn logWindow(context: *Context) void {
    context.begin();
    const ctx = &context.ctx;
    if (ui.beginWindow(context, "Log Window", Rect.init(350, 40, 300, 200), 0) != 0) {
        const layout = [_]c_int{-1};
        _ = context.layoutRow(1, &layout, -25);
        ui.beginPanel(context, "Log Output");
        _ = context.getCurrentContainer();
        _ = context.layoutRow(1, &layout, -1);
        ui.endPandl(ctx);
        var buf = [_]u8{ '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '\n', 0 };
        const layout2 = [_]c_int{ -70, -1 };
        _ = ui.layoutRow(ctx, 2, &layout2, 0);
        if ((ui.textBox(ctx, &buf, buf.len) & microui.MU_RES_SUBMIT) != 0) {
            ui.setFocus(ctx, ctx.last_id);
        }
        ui.endWindow(ctx);
    }
    context.end();
}

pub fn main() !void {
    var context = Context.init(draw.textWidth, draw.textHeight);

    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
        return error.SDLInitFailed;
    }
    defer sdl.SDL_Quit();

    var windowOption: ?*sdl.SDL_Window = null;
    var rendererOption: ?*sdl.SDL_Renderer = null;
    if (!sdl.SDL_CreateWindowAndRenderer(
        "ZigUI",
        800,
        640,
        sdl.SDL_WINDOW_VULKAN,
        &windowOption,
        &rendererOption,
    )) {
        return error.SDLCreateWindowAndRendererFailed;
    }
    const window = windowOption.?;
    const renderer = rendererOption.?;
    defer sdl.SDL_DestroyWindow(window);
    defer sdl.SDL_DestroyRenderer(renderer);

    const icon = try draw.loadAtlas(renderer);
    defer sdl.SDL_DestroyTexture(icon);

    var isRunning = true;
    while (isRunning) {
        var event: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&event)) {
            switch (event.type) {
                sdl.SDL_EVENT_QUIT => isRunning = false,
                sdl.SDL_EVENT_MOUSE_MOTION => context.inputMouseMove(
                    @intFromFloat(event.motion.x),
                    @intFromFloat(event.motion.y),
                ),
                sdl.SDL_EVENT_MOUSE_BUTTON_DOWN, sdl.SDL_EVENT_MOUSE_BUTTON_UP => {
                    const b = switch (event.button.button) {
                        sdl.SDL_BUTTON_LEFT => microui.MU_MOUSE_LEFT,
                        sdl.SDL_BUTTON_RIGHT => microui.MU_MOUSE_RIGHT,
                        sdl.SDL_BUTTON_MIDDLE => microui.MU_MOUSE_MIDDLE,
                        else => 0,
                    };
                    if (b != 0 and event.type == sdl.SDL_EVENT_MOUSE_BUTTON_DOWN) {
                        context.inputMouseDown(
                            @intFromFloat(event.motion.x),
                            @intFromFloat(event.motion.y),
                            b,
                        );
                    }
                    if (b != 0 and event.type == sdl.SDL_EVENT_MOUSE_BUTTON_UP) {
                        context.inputMouseUp(
                            @intFromFloat(event.motion.x),
                            @intFromFloat(event.motion.y),
                            b,
                        );
                    }
                },
                else => {},
            }
        }

        logWindow(&context);

        draw.clear(renderer) catch {
            isRunning = false;
            continue;
        };

        var cmd: [*c]microui.mu_Command = 0;
        while (context.nextCommand(&cmd)) {
            const cmdType = cmd.*;
            const tmp = switch (cmdType.type) {
                microui.MU_COMMAND_RECT => draw.drawRect(renderer, cmdType),
                microui.MU_COMMAND_CLIP => draw.clipRect(renderer, cmdType),
                microui.MU_COMMAND_ICON => draw.drawIcon(renderer, cmdType, icon),
                microui.MU_COMMAND_TEXT => draw.drawText(renderer, cmdType, icon),
                else => {
                    std.debug.print("Not found\n", .{});
                },
            };
            tmp catch {
                isRunning = false;
                continue;
            };
        }

        if (!sdl.SDL_RenderPresent(renderer)) {
            isRunning = false;
            continue;
        }
        sdl.SDL_Delay(16);
    }
}
