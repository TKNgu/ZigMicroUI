const std = @import("std");
const sdl = @import("sdl.zig").sdl;
const math = @import("math.zig");
const draw = @import("sdl.zig").draw;
const Window = @import("sdl.zig").Window;
const Renderer = @import("sdl.zig").Renderer;
const color = @import("color.zig");

pub fn main() !u8 {
    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
        return error.SDLInitFailed;
    }
    defer sdl.SDL_Quit();

    var window = try Window.init("ZigUI", math.vec.Vec2(i32).init(800, 640));
    defer window.deinit();

    var renderer = try Renderer.init(&window);
    defer renderer.deinit();

    const rect = math.rect.Rect2(f32).init(
        math.vec.Vec2(f32).init(0, 0),
        math.vec.Vec2(f32).init(100, 100),
    );

    var isRunning = true;
    while (isRunning) {
        var event: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&event)) {
            switch (event.type) {
                sdl.SDL_EVENT_QUIT => isRunning = false,
                else => {},
            }
        }

        if (!renderer.clear(color.DebugHighContrast.background)) {
            isRunning = false;
            continue;
        }

        draw.fillRect(&renderer, rect, color.DebugHighContrast.background2) catch {
            isRunning = false;
            continue;
        };

        if (!renderer.present()) {
            isRunning = false;
            continue;
        }

        sdl.SDL_Delay(16);
    }

    return 0;
}
