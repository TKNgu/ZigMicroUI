const std = @import("std");
const c_microui = @import("c_microui");

const graphic = @import("graphic");
const sdl = graphic.sdl;
const render = graphic.render;
const style = @import("style.zig");
const math = graphic.math;
const MicroUI = @import("microui/microui.zig").MicroUI;
const styleWindow = @import("ui/style_window.zig").styleWindow;
const LogBuf = @import("ui/log_window.zig").LogBuf;
const logWindow = @import("ui/log_window.zig").logWindow;
const testWindow = @import("ui/test_window.zig").testWindow;
const command_mod = @import("microui/command.zig");

extern "c" fn setenv(name: [*:0]const u8, value: [*:0]const u8, overwrite: c_int) c_int;

var button_map: [256]u8 = [_]u8{0} ** 256;
var key_map: [256]u8 = [_]u8{0} ** 256;
var logbuf = LogBuf.init();
var bg: [3]f32 = .{ 90, 95, 100 };
var checks: [3]i32 = [_]i32{ 1, 0, 1 };

var render_engine: graphic.render.RenderEngine = undefined;

fn textWidth(_: c_microui.mu_Font, text: [*c]const u8, len: c_int) callconv(.c) c_int {
    if (len < 0) {
        const slice = std.mem.span(text);
        var width: i32 = 0;
        for (slice) |c| {
            const char_rect = render_engine.font_atlas.getCharSize(c) catch continue;
            width += @intFromFloat(char_rect.x);
        }
        return width;
    } else {
        const ulen: usize = @intCast(len);
        var width: i32 = 0;
        for (text[0..ulen]) |c| {
            const char_rect = render_engine.font_atlas.getCharSize(c) catch continue;
            width += @intFromFloat(char_rect.x);
        }
        return width;
    }
}

fn textHeight(_: c_microui.mu_Font) callconv(.c) c_int {
    return 22;
}

fn processFrame(microui: *MicroUI) !void {
    microui.begin();
    defer microui.end();

    try styleWindow(microui);
    try logWindow(microui, &logbuf);
    try testWindow(microui, &logbuf, &checks, &bg);
}

pub fn main(init: std.process.Init) !void {
    _ = setenv("XKB_LOG_LEVEL", "critical", 1); // fix xkbcommon warnings on wayland

    const allocator = init.gpa;

    // Init SDL
    graphic.initSDL() catch |err| {
        return err;
    };
    defer graphic.deinitSDL();

    const windowWidth: i32 = 800;
    const windowHeight: i32 = 640;
    var windowOption: ?*sdl.SDL_Window = null;
    var renderOption: ?*sdl.SDL_Renderer = null;
    if (!sdl.SDL_CreateWindowAndRenderer(
        "TheGame",
        windowWidth,
        windowHeight,
        sdl.SDL_WINDOW_VULKAN,
        &windowOption,
        &renderOption,
    )) {
        return error.SDLCreateWindowAndRendererFailed;
    }

    const window = windowOption.?;
    defer sdl.SDL_DestroyWindow(window);
    _ = sdl.SDL_StartTextInput(window);
    defer _ = sdl.SDL_StopTextInput(window);

    const renderer = renderOption.?;
    defer sdl.SDL_DestroyRenderer(renderer);

    // Render engine
    var z_render: graphic.Renderer = .{
        .renderer = renderer,
    };
    const text_color: graphic.color.Color = .{
        .r = 230,
        .g = 230,
        .b = 230,
        .a = 255,
    };
    render_engine = try render.RenderEngine.init(
        allocator,
        &z_render,
        "data/JetBrainsMono-Bold.ttf",
        16,
        text_color,
    );
    defer render_engine.deinit();

    // Init microui
    button_map[sdl.SDL_BUTTON_LEFT & 0xff] = c_microui.MU_MOUSE_LEFT;
    button_map[sdl.SDL_BUTTON_RIGHT & 0xff] = c_microui.MU_MOUSE_RIGHT;
    button_map[sdl.SDL_BUTTON_MIDDLE & 0xff] = c_microui.MU_MOUSE_MIDDLE;

    key_map[sdl.SDLK_LSHIFT & 0xff] = c_microui.MU_KEY_SHIFT;
    key_map[sdl.SDLK_RSHIFT & 0xff] = c_microui.MU_KEY_SHIFT;
    key_map[sdl.SDLK_LCTRL & 0xff] = c_microui.MU_KEY_CTRL;
    key_map[sdl.SDLK_RCTRL & 0xff] = c_microui.MU_KEY_CTRL;
    key_map[sdl.SDLK_LALT & 0xff] = c_microui.MU_KEY_ALT;
    key_map[sdl.SDLK_RALT & 0xff] = c_microui.MU_KEY_ALT;
    key_map[sdl.SDLK_RETURN & 0xff] = c_microui.MU_KEY_RETURN;
    key_map[sdl.SDLK_BACKSPACE & 0xff] = c_microui.MU_KEY_BACKSPACE;

    var microui = try MicroUI.init(allocator, textWidth, textHeight);
    defer microui.deinit(allocator);

    // Main loop
    var is_running = true;
    while (is_running) {
        var event: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&event)) {
            switch (event.type) {
                sdl.SDL_EVENT_QUIT => is_running = false,
                sdl.SDL_EVENT_MOUSE_MOTION => microui.inputMousemove(
                    @as(c_int, @intFromFloat(event.motion.x)),
                    @as(c_int, @intFromFloat(event.motion.y)),
                ),
                sdl.SDL_EVENT_MOUSE_WHEEL => microui.inputScroll(
                    0,
                    @as(c_int, @intFromFloat(event.wheel.y * -30)),
                ),
                sdl.SDL_EVENT_TEXT_INPUT => microui.inputText(event.text.text),
                sdl.SDL_EVENT_MOUSE_BUTTON_DOWN, sdl.SDL_EVENT_MOUSE_BUTTON_UP => {
                    const btn = button_map[event.button.button & 0xff];
                    if (btn != 0 and event.type == sdl.SDL_EVENT_MOUSE_BUTTON_DOWN) {
                        microui.inputMousedown(
                            @as(c_int, @intFromFloat(event.button.x)),
                            @as(c_int, @intFromFloat(event.button.y)),
                            btn,
                        );
                    }
                    if (btn != 0 and event.type == sdl.SDL_EVENT_MOUSE_BUTTON_UP) {
                        microui.inputMouseup(
                            @as(c_int, @intFromFloat(event.button.x)),
                            @as(c_int, @intFromFloat(event.button.y)),
                            btn,
                        );
                    }
                },
                sdl.SDL_EVENT_KEY_DOWN, sdl.SDL_EVENT_KEY_UP => {
                    const index = event.key.key & 0xff;
                    const key = key_map[@as(usize, @intCast(index))];
                    if (key != 0 and event.type == sdl.SDL_EVENT_KEY_DOWN) {
                        microui.inputKeydown(key);
                    }
                    if (key != 0 and event.type == sdl.SDL_EVENT_KEY_UP) {
                        microui.inputKeyup(key);
                    }
                },
                else => {},
            }
        }

        try processFrame(&microui);

        if (!sdl.SDL_SetRenderDrawColor(
            renderer,
            @as(u8, @intFromFloat(bg[0])),
            @as(u8, @intFromFloat(bg[1])),
            @as(u8, @intFromFloat(bg[2])),
            255,
        )) {
            is_running = false;
            continue;
        }
        if (!sdl.SDL_RenderClear(renderer)) {
            is_running = false;
            continue;
        }

        var cmd: ?*command_mod.Command = null;
        while (microui.nextCommand(&cmd) != 0) {
            const cmd_type = cmd.?.type;
            if (cmd_type == command_mod.Type.text) {
                const str_ptr: [*:0]const u8 = @ptrCast(&(cmd.?.text.text[0]));
                const s = std.mem.span(str_ptr);
                const rect = cmd.?.text.pos;
                render_engine.drawText(s, math.vec.Vec2(f32).init(
                    @as(f32, @floatFromInt(rect.x)),
                    @as(f32, @floatFromInt(rect.y)),
                )) catch {};
            } else if (cmd_type == command_mod.Type.rect) {
                const rect = cmd.?.rect;
                const color = cmd.?.rect.color;
                render_engine.fillRect(math.rect.Rect2(f32).init(
                    @as(f32, @floatFromInt(rect.rect.x)),
                    @as(f32, @floatFromInt(rect.rect.y)),
                    @as(f32, @floatFromInt(rect.rect.w)),
                    @as(f32, @floatFromInt(rect.rect.h)),
                ), .{
                    .r = color.r,
                    .g = color.g,
                    .b = color.b,
                    .a = color.a,
                }) catch {};
            } else if (cmd_type == command_mod.Type.icon) {
                const rect = cmd.?.icon.rect;
                const id: usize = @intCast(cmd.?.icon.id);
                render_engine.drawIcon(id, math.rect.Rect2(f32).init(
                    @as(f32, @floatFromInt(rect.x)),
                    @as(f32, @floatFromInt(rect.y)),
                    @as(f32, @floatFromInt(rect.w)),
                    @as(f32, @floatFromInt(rect.h)),
                )) catch {};
            } else if (cmd_type == command_mod.Type.clip) {
                const rect = cmd.?.clip.rect;
                _ = z_render.clip(math.rect.Rect2(f32).init(
                    @as(f32, @floatFromInt(rect.x)),
                    @as(f32, @floatFromInt(rect.y)),
                    @as(f32, @floatFromInt(rect.w)),
                    @as(f32, @floatFromInt(rect.h)),
                ));
            }
        }

        if (!sdl.SDL_RenderPresent(renderer)) {
            is_running = false;
            continue;
        }

        sdl.SDL_Delay(16);
    }
}
