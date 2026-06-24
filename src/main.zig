const std = @import("std");
const sdl = @import("sdl.zig");
const csdl = @import("csdl");
const render = @import("render.zig");
const math = @import("math.zig");
const color = @import("color.zig");
const ui = @import("ui.zig");
const style = @import("style.zig");
const atlas = @import("atlas.zig");

const Container = struct {
    body: math.rect.Rect2(f32),
    view: math.rect.Rect2(f32),
    clip: math.rect.Rect2(f32),

    is_need_scroll_y: bool = false,
    is_need_scroll_x: bool = false,

    pub fn updateClip(self: *Container) void {
        self.clip.pos = self.view.pos;
        self.clip.size.x = if (self.is_need_scroll_x) self.view.size.x - 10 else self.view.size.x;
        self.clip.size.y = if (self.is_need_scroll_y) self.view.size.y - 10 else self.view.size.y;
        self.is_need_scroll_y = self.clip.size.x < self.body.size.x;
        self.is_need_scroll_x = self.clip.size.y < self.body.size.y;
    }

    pub fn updateView(self: *Container, view: math.rect.Rect2(f32)) void {
        const delta = view.pos.sub(self.view.pos);
        self.view = view;
        self.body.pos.selfAdd(delta);
    }

    pub fn getScrollXRect(self: *const Container) ?math.rect.Rect2(f32) {
        return if (self.is_need_scroll_x)
            math.rect.Rect2(f32).init(
                self.clip.pos.x + self.clip.size.x,
                self.clip.pos.y,
                10,
                self.clip.size.y,
            )
        else
            null;
    }

    pub fn getScrollYRect(self: *const Container) ?math.rect.Rect2(f32) {
        return if (self.is_need_scroll_y)
            math.rect.Rect2(f32).init(
                self.clip.pos.x,
                self.clip.pos.y + self.clip.size.y,
                self.clip.size.x,
                10,
            )
        else
            null;
    }
};

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

    var simple_style: style.Style = .{};
    simple_style.color_button = color.DebugHighContrast.button;
    simple_style.color_buttonhover = color.DebugHighContrast.button_hover;
    simple_style.color_buttonfocus = color.DebugHighContrast.button_active;

    var render_engine = try render.RenderEngine.init(
        &renderer,
        "data/JetBrainsMono-Bold.ttf",
        16,
        simple_style.text_color,
    );
    defer render_engine.deinit();

    var window_rect = math.rect.Rect2(f32).init(100, 100, 600, 400);
    var is_window_show = true;
    var left_layout_size: f32 = 200;
    var select_size: f32 = 2;

    var init_container = false;
    var container: Container = undefined;

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

        if (!renderer.clear(90, 95, 100, 255)) {
            is_running = false;
            continue;
        }

        id_logic.begin(is_mouse_down);
        defer id_logic.end();
        var tmp_id = ui.HASH_INITIAL;

        if (is_window_show) {
            var clip_stack = ui.ClipStack.init(window_rect);
            if (!renderer.clip(clip_stack.top())) {
                is_running = false;
                continue;
            }

            try ui.drawFrame(
                &render_engine,
                window_rect,
                simple_style.window_color,
                simple_style.window_border_color,
            );

            var window_layout = ui.createRowLayout(5).init(window_rect, &.{ 20, 20, 20, -15, 0 });
            {
                const titlebar_rect = window_layout.next();
                const titlebar_state = id_logic.update(ui.genSrcLineID(&tmp_id, @src()), titlebar_rect.contains(mouse_pos));
                try ui.drawFrame(
                    &render_engine,
                    titlebar_rect,
                    simple_style.window_titlebar_color,
                    if (titlebar_state == .hover) simple_style.hover_border_color else simple_style.normal_border_color,
                );

                var titlebar_layout = ui.createColumnLayout(2).init(
                    titlebar_rect.pos,
                    titlebar_rect.getWidth(),
                    &.{ -20, 0 },
                );
                const titlebar_title_rect = titlebar_layout.next(titlebar_rect.getHeight());
                const titlebar_title_state = id_logic.update(ui.genSrcLineID(&tmp_id, @src()), titlebar_title_rect.contains(mouse_pos));
                if (titlebar_title_state == .mouse_down) {
                    const delta = math.vec.Vec2(f32).init(
                        mouse_pos.x - last_mouse_post.x,
                        mouse_pos.y - last_mouse_post.y,
                    );
                    window_rect.pos.selfAdd(delta);
                }

                var title_location = titlebar_title_rect.pos;
                title_location.x += 5;
                render_engine.drawText("Hello World!", title_location) catch {
                    is_running = false;
                    continue;
                };

                const titlebar_close_rect = titlebar_layout.next(titlebar_rect.getHeight());
                const titlebar_close_state = id_logic.update(ui.genSrcLineID(&tmp_id, @src()), titlebar_close_rect.contains(mouse_pos));
                if (titlebar_close_state == .mouse_down) {
                    is_window_show = false;
                }

                const border_color = if (titlebar_state == .hover) simple_style.hover_border_color else simple_style.normal_border_color;
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

                var menu_layout = ui.createColumnLayout(5).init(
                    menu_rect.pos,
                    menu_rect.getWidth(),
                    &.{ 50, 50, 50, 50, 50 },
                );
                var count: usize = 0;
                while (count < 5) : (count += 1) {
                    const menu_item_rect = menu_layout.next(menu_rect.getHeight());
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

                var toolbar_layout = ui.createColumnLayout(6).init(
                    toolbar_rect.pos,
                    toolbar_rect.getWidth(),
                    &.{ 20, 20, 20, 20, 20, 20 },
                );
                var count: usize = 0;
                while (count < 10) : (count += 1) {
                    const toolbar_item_rect = toolbar_layout.next(toolbar_rect.getHeight());
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

                var body_layout = ui.createColumnLayout(3).init(
                    body_rect.pos,
                    body_rect.getWidth(),
                    &.{ left_layout_size, select_size, 0 },
                );
                {
                    const body_left_rect = body_layout.next(body_rect.getHeight());
                    if (!init_container) {
                        init_container = true;
                        container.body = body_left_rect;
                        container.view = body_left_rect;
                    }
                    container.updateView(body_left_rect);
                    defer {
                        const scroll_x_rect = container.getScrollXRect();
                        if (scroll_x_rect) |scroll_x| {
                            (ui.drawFrame(
                                &render_engine,
                                scroll_x,
                                simple_style.window_body_color,
                                simple_style.window_body_border_color,
                            )) catch {
                                is_running = false;
                            };
                        }

                        const scroll_y_rect = container.getScrollYRect();
                        if (scroll_y_rect) |scroll_y| {
                            (ui.drawFrame(
                                &render_engine,
                                scroll_y,
                                simple_style.window_body_color,
                                simple_style.window_body_border_color,
                            )) catch {
                                is_running = false;
                            };
                        }
                    }

                    const clip = try clip_stack.push(container.clip);
                    if (!renderer.clip(clip)) {
                        is_running = false;
                        continue;
                    }
                    defer {
                        if (clip_stack.pop()) |clip_top| {
                            if (!renderer.clip(clip_top)) {
                                is_running = false;
                            }
                        } else |err| {
                            std.debug.print("ClipStack.push error: {s}\n", .{@errorName(err)});
                            is_running = false;
                        }
                    }

                    var list_view = ui.createColumnLayout(2).init(
                        container.body.pos,
                        container.body.getWidth(),
                        &.{ 70, 0 },
                    );
                    defer {
                        container.body = list_view.body;
                        container.updateClip();
                    }

                    var count: usize = 0;
                    while (count < 20) : (count += 1) {
                        const key_rect = list_view.next(20);
                        try ui.drawFrame(
                            &render_engine,
                            key_rect,
                            simple_style.window_body_color,
                            simple_style.window_body_border_color,
                        );

                        const value_rect = list_view.next(20);
                        try ui.drawFrame(
                            &render_engine,
                            value_rect,
                            simple_style.window_body_color,
                            simple_style.window_body_border_color,
                        );
                    }
                }

                {
                    const body_left_rect = body_layout.next(body_rect.getHeight());
                    const state = id_logic.update(ui.genSrcLineID(&tmp_id, @src()), body_left_rect.contains(mouse_pos));
                    if (state == .hover or state == .mouse_down) {
                        select_size = 6;
                    } else {
                        select_size = 2;
                    }
                    if (state == .mouse_down) {
                        const delta = math.vec.Vec2(f32).init(
                            mouse_pos.x - last_mouse_post.x,
                            mouse_pos.y - last_mouse_post.y,
                        );
                        left_layout_size += delta.x;
                    }
                    try ui.drawFrame(
                        &render_engine,
                        body_left_rect,
                        simple_style.window_body_color,
                        simple_style.window_body_border_color,
                    );
                }

                {
                    const body_right_rect = body_layout.next(body_rect.getHeight());
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

                var statusbar_layout = ui.createColumnLayout(3).init(
                    statusbar_rect.pos,
                    statusbar_rect.getWidth(),
                    &.{ 100, -30, 0 },
                );
                const statusbar_title_rect = statusbar_layout.next(statusbar_rect.getHeight());
                try ui.drawFrame(
                    &render_engine,
                    statusbar_title_rect,
                    simple_style.window_statusbar_title_color,
                    simple_style.window_statusbar_border_color,
                );

                _ = statusbar_layout.next(statusbar_rect.getHeight());
                const statusbar_close_rect = statusbar_layout.next(statusbar_rect.getHeight());
                try ui.drawFrame(
                    &render_engine,
                    statusbar_close_rect,
                    simple_style.button_color,
                    simple_style.window_statusbar_border_color,
                );
                const close_state = id_logic.update(ui.genSrcLineID(&tmp_id, @src()), statusbar_close_rect.contains(mouse_pos));
                if (close_state == .mouse_down) {
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
