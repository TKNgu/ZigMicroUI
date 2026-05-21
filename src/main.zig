const std = @import("std");
const sdl = @import("sdl.zig");
const csdl = sdl.csdl;
const render = @import("render.zig");
const math = @import("math.zig");
const color = @import("color.zig");

pub fn main() !void {
    if (!csdl.SDL_Init(csdl.SDL_INIT_VIDEO)) {
        return error.SDLInitFailed;
    }
    defer csdl.SDL_Quit();

    var window = try sdl.Window.init("ZigMicroUI", 800, 600);
    defer window.deinit();

    var renderer = try sdl.Renderer.init(&window);
    defer renderer.deinit();

    var render_engine = render.RenderEngine.init(&renderer);

    var is_running = true;
    while (is_running) {
        var e: csdl.SDL_Event = undefined;
        while (csdl.SDL_PollEvent(&e)) {
            switch (e.type) {
                csdl.SDL_EVENT_QUIT => {
                    is_running = false;
                },
                else => {},
            }
        }

        if (!renderer.clear(0, 0, 0, 255)) {
            is_running = false;
            continue;
        }

        try render_engine.rect(math.rect.Rect2(f32).init(
            math.vec.Vec2(f32).init(100, 100),
            math.vec.Vec2(f32).init(100, 100),
        ), color.Nord.success);

        try render_engine.fillRect(math.rect.Rect2(f32).init(
            math.vec.Vec2(f32).init(200, 200),
            math.vec.Vec2(f32).init(100, 100),
        ), color.Nord.danger);

        if (!renderer.present()) {
            is_running = false;
            continue;
        }

        csdl.SDL_Delay(16);
    }
}
