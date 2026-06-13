const std = @import("std");
const sdl = @import("sdl.zig");
const csdl = @import("csdl");
const render = @import("render.zig");
const math = @import("math.zig");
const color = @import("color.zig");
const ui = @import("ui.zig");
const style = @import("style.zig");
const atlas = @import("atlas.zig");

pub fn demoview(
    render_engine: *render.RenderEngine,
    id_logic: *ui.IdLogic,
    mouse_pos: math.vec.Vec2(f32),
    last_mouse_pos: math.vec.Vec2(f32),
) bool {
    const simple_style: style.Style = .{};
    var window_rect = math.rect.Rect2(f32).init(100, 100, 600, 400);
    var tmp_id = ui.HASH_INITIAL;

    try ui.drawFrame(
        render_engine,
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
}

const TextManager = struct {
    font: *csdl.TTF_Font,
    textures: [256]*csdl.SDL_Texture = undefined,

    pub fn init(font: *csdl.TTF_Font) TextManager {
        return .{
            .font = font,
        };
    }
};

pub fn main() !void {
    // Init SDL
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

    var ui_font = try sdl.Font.init("data/JetBrainsMono-Bold.ttf", 16);
    defer ui_font.deinit();

    // Style
    const simple_style: style.Style = .{};

    var font_atlas = try atlas.FontAtlas.init(&ui_font, simple_style.text_color, &renderer);
    defer font_atlas.deinit();

    const info = try ui_font.renderTextTexture("Hello World!", simple_style.text_color, &renderer);
    const text_texture_size = info.size;
    var text_texture = info.texture;
    defer text_texture.deinit();

    // // UI
    // var render_engine = try render.RenderEngine.init(&renderer);

    // // Init state
    var is_running = true;
    // var last_mouse_pos: math.vec.Vec2(f32) = undefined;
    // var mouse_pos: math.vec.Vec2(f32) = undefined;
    // var is_mouse_down = false;

    // // Sample text
    // const text_surface = try ui_font.renderText("Hello World!", simple_style.text_color);
    // defer csdl.SDL_DestroySurface(text_surface);
    // const text_texture = csdl.SDL_CreateTextureFromSurface(renderer.renderer, text_surface);
    // if (text_texture == null) {
    //     const error_log = csdl.SDL_GetError();
    //     std.debug.print("SDL_CreateTextureFromSurface failed: {s}\n", .{error_log});
    //     return error.SDLCreateTextureFromSurfaceFailed;
    // }
    // defer csdl.SDL_DestroyTexture(text_texture);

    // Main loop
    while (is_running) {
        // Handle SDL events
        // last_mouse_pos = mouse_pos;
        var e: csdl.SDL_Event = undefined;
        while (csdl.SDL_PollEvent(&e)) {
            switch (e.type) {
                csdl.SDL_EVENT_QUIT => {
                    is_running = false;
                },
                // csdl.SDL_EVENT_MOUSE_MOTION => {
                //     mouse_pos.x = e.motion.x;
                //     mouse_pos.y = e.motion.y;
                // },
                // csdl.SDL_EVENT_MOUSE_BUTTON_DOWN => {
                //     is_mouse_down = true;
                // },
                // csdl.SDL_EVENT_MOUSE_BUTTON_UP => {
                //     is_mouse_down = false;
                // },
                else => {},
            }
        }

        if (!renderer.clear(90, 95, 100, 255)) {
            is_running = false;
            continue;
        }

        const dst_rect = math.rect.Rect2(f32).init(
            100,
            100,
            @floatFromInt(text_texture_size.x),
            @floatFromInt(text_texture_size.y),
        );
        text_texture.render(&renderer, null, dst_rect) catch {
            is_running = false;
            continue;
        };

        font_atlas.atlas_texture.render(&renderer, null, null) catch {
            is_running = false;
            continue;
        };

        const location = math.vec.Vec2(f32).init(10, 10);
        font_atlas.renderChar(&renderer, 'C', location) catch {
            is_running = false;
            continue;
        };

        var tmp = ui_font.renderTextTexture("Hello World!", simple_style.text_color, &renderer) catch {
            is_running = false;
            continue;
        };
        defer tmp.texture.deinit();

        const text_size = tmp.size;
        tmp.texture.render(&renderer, null, math.rect.Rect2(f32).initVec(
            math.vec.Vec2(f32).init(10, 10),
            math.vec.Vec2(f32).init(
                @floatFromInt(text_size.x),
                @floatFromInt(text_size.y),
            ),
        )) catch {
            is_running = false;
            continue;
        };

        // try render_engine.drawTexture(text_texture, null, null);
        //
        // ui.drawFrame(
        //     &render_engine,
        //     math.rect.Rect2(f32).init(100, 100, 600, 400),
        //     simple_style.color_windowbg,
        //     simple_style.color_border,
        // ) catch {
        //     is_running = false;
        //     continue;
        // };
        //
        // ui.drawFrame(
        //     &render_engine,
        //     math.rect.Rect2(f32).init(100, 100, 600, 20),
        //     simple_style.color_titlebg,
        //     simple_style.color_border,
        // ) catch {
        //     is_running = false;
        //     continue;
        // };
        //
        // var start_location = math.vec.Vec2(f32).init(10, 10);
        // var max_height: f32 = 0;
        //
        // for (32..128) |c| {
        //     const sample_rect = atlas.ATLAS_FONT[c];
        //     const dst_rect = math.rect.Rect2(f32).init(start_location.x, start_location.y, sample_rect.getWidth() * 2, sample_rect.getHeight() * 2);
        //
        //     start_location.x += dst_rect.getWidth() + 1;
        //     max_height = if (max_height < dst_rect.getHeight()) dst_rect.getHeight() else max_height;
        //
        //     if (start_location.x > 500) {
        //         start_location.x = 10;
        //         start_location.y += max_height + 1;
        //     }
        // }

        if (!renderer.present()) {
            is_running = false;
            continue;
        }

        csdl.SDL_Delay(16);
    }
}
