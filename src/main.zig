const std = @import("std");
const sdl = @import("sdl.zig");
const csdl = @import("csdl");
const render = @import("render.zig");
const math = @import("math.zig");
const color = @import("color.zig");
const ui = @import("ui.zig");
const style = @import("style.zig");
const atlas = @import("atlas.zig");

pub fn main() !void {
    if (!csdl.SDL_Init(csdl.SDL_INIT_VIDEO)) {
        const error_log = csdl.SDL_GetError();
        std.debug.print("SDL_Init failed: {s}\n", .{error_log});
        return error.SDLInitFailed;
    }
    defer csdl.SDL_Quit();

    if (!csdl.TTF_Init()) {
        const error_log = csdl.SDL_GetError();
        std.debug.print("TTF_Init failed: {s}\n", .{error_log});
        return error.TTFInitFailed;
    }
    defer csdl.TTF_Quit();

    var window = try sdl.Window.init("ZigMicroUI", 800, 600);
    defer window.deinit();

    var renderer = try sdl.Renderer.init(&window);
    defer renderer.deinit();

    var last_mouse_post: math.vec.Vec2(f32) = undefined;
    var mouse_pos: math.vec.Vec2(f32) = undefined;
    var is_mouse_down = false;
    var id_logic = ui.IdLogic{};

    const simple_style: style.Style = .{};
    var render_engine = try render.RenderEngine.init(
        &renderer,
        "data/JetBrainsMono-Bold.ttf",
        16,
        simple_style.text_color,
    );
    defer render_engine.deinit();

    var window_rect = math.rect.Rect2(f32).init(100, 100, 600, 400);
    var is_window_show = true;

    var is_running = true;
    while (is_running) {
        last_mouse_post = mouse_pos;
        var event: csdl.SDL_Event = undefined;
        while (csdl.SDL_PollEvent(&event)) {
            switch (event.type) {
                csdl.SDL_EVENT_QUIT => {
                    is_running = false;
                    continue;
                },
                csdl.SDL_EVENT_MOUSE_MOTION => {
                    mouse_pos.x = event.motion.x;
                    mouse_pos.y = event.motion.y;
                },
                csdl.SDL_EVENT_MOUSE_BUTTON_DOWN => {
                    is_mouse_down = true;
                },
                csdl.SDL_EVENT_MOUSE_BUTTON_UP => {
                    is_mouse_down = false;
                },
                else => {},
            }
        }

        var tmp_id = ui.HASH_INITIAL;
        id_logic.updateMouse(mouse_pos, is_mouse_down);
        defer id_logic.resetMouseDown();

        if (!renderer.clear(90, 95, 100, 255)) {
            is_running = false;
            continue;
        }

        if (is_window_show) {
            try ui.drawFrame(
                &render_engine,
                window_rect,
                simple_style.window_color,
                simple_style.window_border_color,
            );

            var window_layout = ui.createRowLayout(5).init(window_rect, &.{ 20, 20, 20, -15, 15 });
            {
                const titlebar_rect = window_layout.next();
                try ui.drawFrame(
                    &render_engine,
                    titlebar_rect,
                    simple_style.window_titlebar_color,
                    simple_style.normal_border_color,
                );

                var titlebar_layout = ui.createColumnLayout(3).init(titlebar_rect, &.{ 100, -20, 20 });
                const titlebar_title_rect = titlebar_layout.next();
                var title_location = titlebar_title_rect.pos;
                title_location.x += 5;
                render_engine.drawText("Hello World!", title_location) catch {
                    is_running = false;
                    continue;
                };

                const mover_rect = titlebar_layout.next();
                ui.genSrcLineID(&tmp_id, @src());
                if (id_logic.updateMouseDown(mover_rect, tmp_id)) {
                    const delta = math.vec.Vec2(f32).init(
                        mouse_pos.x - last_mouse_post.x,
                        mouse_pos.y - last_mouse_post.y,
                    );
                    window_rect.pos.selfAdd(delta);
                }

                const titlebar_close_rect = titlebar_layout.next();
                ui.genSrcLineID(&tmp_id, @src());
                if (id_logic.updateMouseUp(titlebar_close_rect, tmp_id)) {
                    id_logic.resetMouseUp();
                    std.debug.print("mouse up\n", .{});
                    is_window_show = false;
                }

                const border_color = if (id_logic.getIsHover(tmp_id)) simple_style.hover_border_color else simple_style.normal_border_color;
                try ui.drawFrame(
                    &render_engine,
                    titlebar_close_rect,
                    simple_style.button_color,
                    border_color,
                );
            }

            {
                const menu_rect = window_layout.next();
                try ui.drawFrame(
                    &render_engine,
                    menu_rect,
                    simple_style.menu_color,
                    simple_style.menu_border_color,
                );

                var menu_layout = ui.createColumnLayout(5).init(menu_rect, &.{ 50, 50, 50, 50, 50 });
                var count: usize = 0;
                while (count < 5) : (count += 1) {
                    const menu_item_rect = menu_layout.next();
                    try ui.drawFrame(
                        &render_engine,
                        menu_item_rect,
                        simple_style.menu_text_color,
                        simple_style.menu_border_color,
                    );
                }
            }

            {
                const toolbar_rect = window_layout.next();
                try ui.drawFrame(
                    &render_engine,
                    toolbar_rect,
                    simple_style.menu_color,
                    simple_style.menu_border_color,
                );

                var toolbar_layout = ui.createColumnLayout(6).init(toolbar_rect, &.{ 20, 20, 20, 20, 20, 20 });
                var count: usize = 0;
                while (count < 10) : (count += 1) {
                    const toolbar_item_rect = toolbar_layout.next();
                    try ui.drawFrame(
                        &render_engine,
                        toolbar_item_rect,
                        simple_style.menu_text_color,
                        simple_style.menu_border_color,
                    );
                }
            }

            {
                const body_rect = window_layout.next();
                try ui.drawFrame(
                    &render_engine,
                    body_rect,
                    simple_style.window_body_color,
                    simple_style.window_body_border_color,
                );

                var body_layout = ui.createColumnLayout(2).init(body_rect, &.{ 200, 0 });
                {
                    const body_left_rect = body_layout.next();
                    try ui.drawFrame(
                        &render_engine,
                        body_left_rect,
                        simple_style.window_body_color,
                        simple_style.window_body_border_color,
                    );
                }

                {
                    const body_right_rect = body_layout.next();
                    try ui.drawFrame(
                        &render_engine,
                        body_right_rect,
                        simple_style.window_body_color,
                        simple_style.window_body_border_color,
                    );
                }
            }

            {
                const statusbar_rect = window_layout.next();
                try ui.drawFrame(
                    &render_engine,
                    statusbar_rect,
                    simple_style.window_statusbar_color,
                    simple_style.window_statusbar_border_color,
                );

                var statusbar_layout = ui.createColumnLayout(3).init(statusbar_rect, &.{ 100, -30, 30 });
                const statusbar_title_rect = statusbar_layout.next();
                try ui.drawFrame(
                    &render_engine,
                    statusbar_title_rect,
                    simple_style.window_statusbar_title_color,
                    simple_style.window_statusbar_border_color,
                );

                _ = statusbar_layout.next();
                const statusbar_close_rect = statusbar_layout.next();
                try ui.drawFrame(
                    &render_engine,
                    statusbar_close_rect,
                    simple_style.button_color,
                    simple_style.window_statusbar_border_color,
                );
                ui.genSrcLineID(&tmp_id, @src());
                if (id_logic.updateMouseDown(statusbar_close_rect, tmp_id)) {
                    const delta = math.vec.Vec2(f32).init(
                        mouse_pos.x - last_mouse_post.x,
                        mouse_pos.y - last_mouse_post.y,
                    );
                    window_rect.size.selfAdd(delta);
                }
            }
        }

        if (!renderer.present()) {
            is_running = false;
            continue;
        }

        csdl.SDL_Delay(16);
    }
}
