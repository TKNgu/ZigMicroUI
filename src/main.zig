const std = @import("std");
const sdl = @import("sdl.zig").sdl;
const microui = @import("sdl.zig").microui;
const draw = @import("draw.zig");
const atlas = @import("sdl.zig").atlas;
const ui = @import("ui.zig");

fn drawWindow(ctx: *microui.mu_Context) void {
    ui.begin(ctx);
    const windowRect = ui.muRect(350, 250, 300, 240);
    ui.beginWindow(ctx, "View", windowRect, 0);
    if (microui.mu_begin_window(ctx, "View", windowRect) != 0) {
        const layour = [_]c_int{-1};
        microui.mu_layout_row(ctx, 1, &layour, -25);
        microui.mu_begin_panel(ctx, "Log Output");
        _ = microui.mu_get_current_container(ctx);
        microui.mu_layout_row(ctx, 1, &layour, -1);
        microui.mu_label(ctx, "Blue:");
        microui.mu_end_panel(ctx);
        microui.mu_end_window(ctx);
    }
    microui.mu_end(ctx);
}

pub fn main() !void {
    var ctx: microui.mu_Context = undefined;
    ui.muInit(&ctx);
    ctx.text_width = draw.textWidth;
    ctx.text_height = draw.textHeight;

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
                sdl.SDL_EVENT_MOUSE_MOTION => microui.mu_input_mousemove(
                    &ctx,
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
                    const x: i32 = @intFromFloat(event.motion.x);
                    const y: i32 = @intFromFloat(event.motion.y);
                    if (b != 0 and event.type == sdl.SDL_EVENT_MOUSE_BUTTON_DOWN) {
                        microui.mu_input_mousedown(&ctx, x, y, b);
                    }
                    if (b != 0 and event.type == sdl.SDL_EVENT_MOUSE_BUTTON_UP) {
                        microui.mu_input_mouseup(&ctx, x, y, b);
                    }
                },
                else => {},
            }
        }

        drawWindow(&ctx);

        draw.clear(renderer) catch {
            isRunning = false;
            continue;
        };

        var cmd: [*c]microui.mu_Command = 0;
        while (microui.mu_next_command(&ctx, &cmd) != 0) {
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
