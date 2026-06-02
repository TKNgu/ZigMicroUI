const std = @import("std");
const sdl = @import("sdl.zig");
const csdl = sdl.csdl;
const render = @import("render.zig");
const math = @import("math.zig");
const color = @import("color.zig");
const ui = @import("ui.zig");
const style = @import("style.zig");

pub fn main() !void {

    // Init SDL
    if (!csdl.SDL_Init(csdl.SDL_INIT_VIDEO)) {
        return error.SDLInitFailed;
    }
    defer csdl.SDL_Quit();

    var window = try sdl.Window.init("ZigMicroUI", 800, 600);
    defer window.deinit();

    var renderer = try sdl.Renderer.init(&window);
    defer renderer.deinit();

    var render_engine = render.RenderEngine.init(&renderer);
    const simple_style: style.Style = .{};

    // Init state
    var is_running = true;
    var last_mouse_pos: math.vec.Vec2(f32) = undefined;
    var mouse_pos: math.vec.Vec2(f32) = undefined;
    var is_mouse_down = false;

    var id_logic = ui.IdLogic{};
    // var hover_id: ?ui.ID = undefined;
    // var mouse_down_id: ?ui.ID = null;
    // var mouse_up_id: ?ui.ID = null;

    var window_rect = math.rect.Rect2(f32).init(100, 100, 600, 400);

    // Main loop
    while (is_running) {
        // Handle SDL events
        last_mouse_pos = mouse_pos;
        var e: csdl.SDL_Event = undefined;
        while (csdl.SDL_PollEvent(&e)) {
            switch (e.type) {
                csdl.SDL_EVENT_QUIT => {
                    is_running = false;
                },
                csdl.SDL_EVENT_MOUSE_MOTION => {
                    mouse_pos.x = e.motion.x;
                    mouse_pos.y = e.motion.y;
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

        // Init id
        var tmp_id = ui.HASH_INITIAL;
        // hover_id = null;
        id_logic.updateMouse(mouse_pos, is_mouse_down);
        defer id_logic.resetMouseDown();

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
            try ui.drawFrame(
                &render_engine,
                titlebar_title_rect,
                simple_style.window_titlebar_title_color,
                simple_style.normal_border_color,
            );

            const mover_rect = titlebar_layout.next();
            ui.genSrcLineID(&tmp_id, @src());
            if (id_logic.updateMouseDown(mover_rect, tmp_id)) {
                const delta = math.vec.Vec2(f32).init(mouse_pos.x - last_mouse_pos.x, mouse_pos.y - last_mouse_pos.y);
                window_rect.pos.selfAdd(delta);
            }

            const titlebar_close_rect = titlebar_layout.next();
            ui.genSrcLineID(&tmp_id, @src());
            if (id_logic.updateMouseUp(titlebar_close_rect, tmp_id)) {
                id_logic.resetMouseUp();
                std.debug.print("mouse up\n", .{});
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
        }

        if (!renderer.present()) {
            is_running = false;
            continue;
        }

        csdl.SDL_Delay(16);
    }
}
