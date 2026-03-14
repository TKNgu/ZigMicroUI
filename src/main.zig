const std = @import("std");
const sdl = @import("sdl.zig").sdl;

pub fn main() !void {
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

    var isRunning = true;
    while (isRunning) {
        var event: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&event)) {
            switch (event.type) {
                sdl.SDL_EVENT_QUIT => isRunning = false,
                else => {},
            }
        }

        if (!sdl.SDL_RenderClear(renderer)) {
            isRunning = false;
            continue;
        }

        if (!sdl.SDL_RenderPresent(renderer)) {
            isRunning = false;
            continue;
        }

        sdl.SDL_Delay(16);
    }
}
