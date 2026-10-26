const std = @import("std");
const graphic = @import("graphic");
const sdl = graphic.sdl;
const render = graphic.render;
const math = graphic.math;
const microui_mod = @import("microui/microui.zig");
const MicroUI = microui_mod.MicroUI;
const styleWindow = @import("ui/style_window.zig").styleWindow;
const LogBuf = @import("ui/log_window.zig").LogBuf;
const logWindow = @import("ui/log_window.zig").logWindow;
const testWindow = @import("ui/test_window.zig").testWindow;
const command_mod = @import("microui/command.zig");
const clearWindow = @import("ui/clear_window.zig").clearWindow;

extern "c" fn setenv(name: [*:0]const u8, value: [*:0]const u8, overwrite: c_int) c_int;

var button_map: [256]microui_mod.Mouse = [_]microui_mod.Mouse{.none} ** 256;
var key_map: [256]microui_mod.Key = [_]microui_mod.Key{.none} ** 256;
var logbuf = LogBuf.init();
var bg: [3]f32 = .{ 90, 95, 100 };
var checks: [3]i32 = [_]i32{ 1, 0, 1 };

var render_engine: graphic.render.RenderEngine = undefined;

fn textWidth(_: microui_mod.Font, text: [*c]const u8, len: c_int) callconv(.c) c_int {
    if (text == null) return 0;
    if (len < 0) {
        const slice = std.mem.span(text);
        return render_engine.getTextWidth(slice) catch 0;
    } else {
        const ulen: usize = @intCast(len);
        return render_engine.getTextWidth(text[0..ulen]) catch 0;
    }
}

fn textHeight(_: microui_mod.Font) callconv(.c) c_int {
    return 22;
}

fn processFrame(microui: *MicroUI) !void {
    microui.begin();
    defer microui.end();

    try styleWindow(microui);
    try logWindow(microui, &logbuf);
    try testWindow(microui, &logbuf, &checks, &bg);
    try clearWindow(microui);
}

pub fn main(init: std.process.Init) !void {
    _ = setenv("XKB_LOG_LEVEL", "critical", 1); // fix xkbcommon warnings on wayland

    const allocator = init.gpa;

    // Init SDL
    graphic.initSDL() catch |err| {
        std.log.err("Failed to initialize SDL subsystem: {s}", .{@errorName(err)});
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
        std.log.err("SDL_CreateWindowAndRenderer failed: {s}", .{sdl.SDL_GetError()});
        return error.SDLCreateWindowAndRendererFailed;
    }

    const window = windowOption.?;
    defer sdl.SDL_DestroyWindow(window);
    if (!sdl.SDL_StartTextInput(window)) {
        std.log.warn("SDL_StartTextInput failed: {s}", .{sdl.SDL_GetError()});
    }
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
    render_engine = render.RenderEngine.init(
        allocator,
        &z_render,
        "data/JetBrainsMono-Bold.ttf",
        16,
        text_color,
    ) catch |err| {
        std.log.err("Failed to initialize RenderEngine: {s}", .{@errorName(err)});
        return err;
    };
    defer render_engine.deinit();

    // Init microui
    button_map[sdl.SDL_BUTTON_LEFT & 0xff] = .left;
    button_map[sdl.SDL_BUTTON_RIGHT & 0xff] = .right;
    button_map[sdl.SDL_BUTTON_MIDDLE & 0xff] = .middle;

    key_map[sdl.SDLK_LSHIFT & 0xff] = .shift;
    key_map[sdl.SDLK_RSHIFT & 0xff] = .shift;
    key_map[sdl.SDLK_LCTRL & 0xff] = .ctrl;
    key_map[sdl.SDLK_RCTRL & 0xff] = .ctrl;
    key_map[sdl.SDLK_LALT & 0xff] = .alt;
    key_map[sdl.SDLK_RALT & 0xff] = .alt;
    key_map[sdl.SDLK_RETURN & 0xff] = .@"return";
    key_map[sdl.SDLK_BACKSPACE & 0xff] = .backspace;

    var microui = MicroUI.init(allocator, textWidth, textHeight) catch |err| {
        std.log.err("Failed to initialize MicroUI: {s}", .{@errorName(err)});
        return err;
    };
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
                    if (btn != .none and event.type == sdl.SDL_EVENT_MOUSE_BUTTON_DOWN) {
                        microui.inputMousedown(
                            @as(c_int, @intFromFloat(event.button.x)),
                            @as(c_int, @intFromFloat(event.button.y)),
                            btn,
                        );
                    }
                    if (btn != .none and event.type == sdl.SDL_EVENT_MOUSE_BUTTON_UP) {
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
                    if (key != .none and event.type == sdl.SDL_EVENT_KEY_DOWN) {
                        microui.inputKeydown(key);
                    }
                    if (key != .none and event.type == sdl.SDL_EVENT_KEY_UP) {
                        microui.inputKeyup(key);
                    }
                },
                else => {},
            }
        }

        processFrame(&microui) catch |err| {
            std.log.err("processFrame failed: {s}", .{@errorName(err)});
            break;
        };

        if (!sdl.SDL_SetRenderDrawColor(
            renderer,
            @as(u8, @intFromFloat(bg[0])),
            @as(u8, @intFromFloat(bg[1])),
            @as(u8, @intFromFloat(bg[2])),
            255,
        )) {
            std.log.err("SDL_SetRenderDrawColor failed: {s}", .{sdl.SDL_GetError()});
            break;
        }
        if (!sdl.SDL_RenderClear(renderer)) {
            std.log.err("SDL_RenderClear failed: {s}", .{sdl.SDL_GetError()});
            break;
        }

        var cmd: ?*command_mod.Command = null;
        while (microui.nextCommand(&cmd)) {
            if (cmd) |c| {
                switch (c.type) {
                    .text => {
                        const text_cmd = &c.text;
                        render_engine.drawText(text_cmd.getSlice(), math.vec.Vec2(f32).init(
                            @as(f32, @floatFromInt(text_cmd.pos.x)),
                            @as(f32, @floatFromInt(text_cmd.pos.y)),
                        )) catch |err| {
                            std.log.warn("drawText failed: {s}", .{@errorName(err)});
                        };
                    },
                    .rect => {
                        const r = c.rect.rect;
                        const color = c.rect.color;
                        render_engine.fillRect(math.rect.Rect2(f32).init(
                            @as(f32, @floatFromInt(r.x)),
                            @as(f32, @floatFromInt(r.y)),
                            @as(f32, @floatFromInt(r.w)),
                            @as(f32, @floatFromInt(r.h)),
                        ), .{
                            .r = color.r,
                            .g = color.g,
                            .b = color.b,
                            .a = color.a,
                        }) catch |err| {
                            std.log.warn("fillRect failed: {s}", .{@errorName(err)});
                        };
                    },
                    .icon => {
                        const r = c.icon.rect;
                        const id: usize = @intCast(@intFromEnum(c.icon.icon));
                        render_engine.drawIcon(id, math.rect.Rect2(f32).init(
                            @as(f32, @floatFromInt(r.x)),
                            @as(f32, @floatFromInt(r.y)),
                            @as(f32, @floatFromInt(r.w)),
                            @as(f32, @floatFromInt(r.h)),
                        )) catch |err| {
                            std.log.warn("drawIcon failed: {s}", .{@errorName(err)});
                        };
                    },
                    .clip => {
                        const r = c.clip.rect;
                        _ = z_render.clip(math.rect.Rect2(f32).init(
                            @as(f32, @floatFromInt(r.x)),
                            @as(f32, @floatFromInt(r.y)),
                            @as(f32, @floatFromInt(r.w)),
                            @as(f32, @floatFromInt(r.h)),
                        ));
                    },
                    else => {},
                }
            }
        }

        // while (zmicroui.nextCommand(&cmd)) {
        //     if (cmd) |c| {
        //         switch (c.type) {
        //             .text => {
        //                 const text_cmd = &c.text;
        //                 render_engine.drawText(text_cmd.getSlice(), math.vec.Vec2(f32).init(
        //                     @as(f32, @floatFromInt(text_cmd.pos.x)),
        //                     @as(f32, @floatFromInt(text_cmd.pos.y)),
        //                 )) catch |err| {
        //                     std.log.warn("drawText failed: {s}", .{@errorName(err)});
        //                 };
        //             },
        //             .rect => {
        //                 const r = c.rect.rect;
        //                 const color = c.rect.color;
        //                 render_engine.fillRect(math.rect.Rect2(f32).init(
        //                     @as(f32, @floatFromInt(r.x)),
        //                     @as(f32, @floatFromInt(r.y)),
        //                     @as(f32, @floatFromInt(r.w)),
        //                     @as(f32, @floatFromInt(r.h)),
        //                 ), .{
        //                     .r = color.r,
        //                     .g = color.g,
        //                     .b = color.b,
        //                     .a = color.a,
        //                 }) catch |err| {
        //                     std.log.warn("fillRect failed: {s}", .{@errorName(err)});
        //                 };
        //             },
        //             .icon => {
        //                 const r = c.icon.rect;
        //                 const id: usize = @intCast(c.icon.id);
        //                 render_engine.drawIcon(id, math.rect.Rect2(f32).init(
        //                     @as(f32, @floatFromInt(r.x)),
        //                     @as(f32, @floatFromInt(r.y)),
        //                     @as(f32, @floatFromInt(r.w)),
        //                     @as(f32, @floatFromInt(r.h)),
        //                 )) catch |err| {
        //                     std.log.warn("drawIcon failed: {s}", .{@errorName(err)});
        //                 };
        //             },
        //             .clip => {
        //                 const r = c.clip.rect;
        //                 _ = z_render.clip(math.rect.Rect2(f32).init(
        //                     @as(f32, @floatFromInt(r.x)),
        //                     @as(f32, @floatFromInt(r.y)),
        //                     @as(f32, @floatFromInt(r.w)),
        //                     @as(f32, @floatFromInt(r.h)),
        //                 ));
        //             },
        //             else => {},
        //         }
        //     }
        // }

        if (!sdl.SDL_RenderPresent(renderer)) {
            std.log.err("SDL_RenderPresent failed: {s}", .{sdl.SDL_GetError()});
            break;
        }

        sdl.SDL_Delay(16);
    }
}
