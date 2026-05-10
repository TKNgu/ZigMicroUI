const std = @import("std");
const sdl = @import("sdl.zig").sdl;
const math = @import("math.zig");
const draw = @import("sdl.zig").draw;
const Window = @import("sdl.zig").Window;
const Renderer = @import("sdl.zig").Renderer;
const DrawEngine = @import("sdl.zig").DrawEngine;
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

    const theme = color.DebugHighContrast;
    var draw_engine = DrawEngine.init(theme.background);

    const rect = math.rect.Rect2(f32).init(
        math.vec.Vec2(f32).init(0, 0),
        math.vec.Vec2(f32).init(100, 100),
    );

    var isRunning = true;
    while (isRunning) {
        // Handle events
        var event: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&event)) {
            switch (event.type) {
                sdl.SDL_EVENT_QUIT => isRunning = false,
                else => {},
            }
        }

        // Draw ui
        draw_engine.reset();
        draw_engine.push(.{ .FillRect = .{
            .rect_draw = rect,
            .color = theme.panel,
        } }) catch {
            isRunning = false;
            continue;
        };
        draw_engine.push(.{ .Rect = .{
            .rect_draw = rect,
            .color = theme.text,
        } }) catch {
            isRunning = false;
            continue;
        };

        // Render ui
        draw_engine.render(&renderer) catch {
            isRunning = false;
            continue;
        };
        sdl.SDL_Delay(16);
    }

    return 0;
}
