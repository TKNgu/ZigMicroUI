const std = @import("std");
const sdl = @import("sdl.zig");
const csdl = sdl.csdl;
const render = @import("render.zig");
const math = @import("math.zig");
const color = @import("color.zig");
const ui = @import("ui.zig");
const style = @import("style.zig");

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
    var simple_style: style.Style = .{};

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

        const background_color = simple_style.background_color;
        if (!renderer.clear(
            background_color.r,
            background_color.g,
            background_color.b,
            background_color.a,
        )) {
            is_running = false;
            continue;
        }

        const window_rect = math.rect.Rect2(f32).init(
            100,
            100,
            600,
            400,
        );
        try ui.drawWindow(
            &render_engine,
            &simple_style,
            window_rect,
        );

        const layout_body = math.rect.Rect2(f32).init(
            window_rect.getX(),
            window_rect.getY() + simple_style.window_titlebar_size,
            window_rect.getWidth(),
            window_rect.getHeight() - simple_style.window_titlebar_size - simple_style.window_statusbar_size,
        );
        var layout = ui.createLayout(2).init(
            layout_body,
            &[_]f32{ 100, -300 },
            20,
        );
        var count: usize = 0;
        while (count < 10) : (count += 1) {
            {
                const rect = layout.next();
                try ui.drawFrame(
                    &render_engine,
                    rect,
                    color.Nord.danger,
                    color.Nord.border,
                );
            }
            {
                const rect = layout.next();
                try ui.drawFrame(
                    &render_engine,
                    rect,
                    color.Nord.danger,
                    color.Nord.border,
                );
            }
        }

        // count = 0;
        // while (count < 3) : (count += 1) {
        //     var sub_count: usize = 0;
        //     while (sub_count < 4) : (sub_count += 1) {
        //         const rect = layout.next();
        //         try ui.drawFrame(
        //             &render_engine,
        //             rect,
        //             color.Nord.danger,
        //             color.Nord.border,
        //         );
        //     }
        // }

        if (!renderer.present()) {
            is_running = false;
            continue;
        }

        csdl.SDL_Delay(16);
    }
}
