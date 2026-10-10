const std = @import("std");
const c_microui = @import("c_microui");

const graphic = @import("graphic");
const sdl = graphic.sdl;
const render = graphic.render;
const style = @import("style.zig");
const math = graphic.math;

const MicroUI = @import("microui/microui.zig").MicroUI;

var button_map: [256]u8 = [_]u8{0} ** 256;
var key_map: [256]u8 = [_]u8{0} ** 256;
var logbuf = LogBuf.init();
var bg: [3]f32 = .{ 90, 95, 100 };
var checks: [3]i32 = [_]i32{ 1, 0, 1 };

const LogBuf = struct {
    buf: [64000]u8 = undefined,
    offset: usize = 0,
    updated: bool = false,

    fn init() LogBuf {
        return .{
            .buf = [_]u8{0} ** 64000,
        };
    }

    fn write(self: *LogBuf, text: []const u8) void {
        @memmove(self.buf[self.offset .. self.offset + text.len], text);
        self.offset += text.len;
        self.buf[self.offset] = '\n';
        self.updated = true;
    }
};

var render_engine: graphic.render.RenderEngine = undefined;

fn textWidth(_: c_microui.mu_Font, text: [*c]const u8, len: c_int) callconv(.c) c_int {
    if (len < 0) {
        var p: [*c]u8 = @constCast(text);
        var size: usize = 0;
        while (p.* != 0) : (p += 1) {
            size += 1;
        }
        var s: [:0]u8 = undefined;
        s.ptr = @constCast(text);
        s.len = size;
        return render_engine.getTextWidth(s) catch 0;
    } else {
        var s: [:0]u8 = undefined;
        s.ptr = @constCast(text);
        s.len = @as(usize, @intCast(len));
        return render_engine.getTextWidth(s) catch 0;
    }
}

fn textHeight(_: c_microui.mu_Font) callconv(.c) c_int {
    return 22;
}

fn uint8Slider(ctx: [*c]c_microui.mu_Context, value: *u8, low: i32, high: i32) i32 {
    c_microui.mu_push_id(ctx, @ptrCast(&value), @sizeOf(u8));
    var tmp: f32 = @floatFromInt(value.*);
    const res = c_microui.mu_slider_ex(
        ctx,
        &tmp,
        @floatFromInt(low),
        @floatFromInt(high),
        0,
        "%.0f",
        c_microui.MU_OPT_ALIGNCENTER,
    );
    value.* = @intFromFloat(tmp);
    c_microui.mu_pop_id(ctx);
    return res;
}

fn styleWindow(ctx: [*c]c_microui.mu_Context, microui: *MicroUI) !void {
    const Color = struct {
        label: [:0]const u8,
        idx: usize,
    };
    const colors = [_]Color{
        .{ .label = "text"[0..], .idx = c_microui.MU_COLOR_TEXT },
        .{ .label = "border", .idx = c_microui.MU_COLOR_BORDER },
        .{ .label = "windowbg", .idx = c_microui.MU_COLOR_WINDOWBG },
        .{ .label = "titlebg", .idx = c_microui.MU_COLOR_TITLEBG },
        .{ .label = "titletext", .idx = c_microui.MU_COLOR_TITLETEXT },
        .{ .label = "panelbg", .idx = c_microui.MU_COLOR_PANELBG },
        .{ .label = "button", .idx = c_microui.MU_COLOR_BUTTON },
        .{ .label = "buttonhover", .idx = c_microui.MU_COLOR_BUTTONHOVER },
        .{ .label = "buttonfocus", .idx = c_microui.MU_COLOR_BUTTONFOCUS },
        .{ .label = "base", .idx = c_microui.MU_COLOR_BASE },
        .{ .label = "basehover", .idx = c_microui.MU_COLOR_BASEHOVER },
        .{ .label = "basefocus", .idx = c_microui.MU_COLOR_BASEFOCUS },
        .{ .label = "scrollbase", .idx = c_microui.MU_COLOR_SCROLLBASE },
        .{ .label = "scrollthumb", .idx = c_microui.MU_COLOR_SCROLLTHUMB },
    };
    try microui.beginWindow("Style Editor", c_microui.mu_rect(350, 250, 300, 240));
    defer microui.endWindow();

    const size_width: i32 =
        @intFromFloat(@as(f32, @floatFromInt(microui.getCurrentContainer().*.body.w)) * 0.14);
    microui.layoutRow(&[_]i32{ 80, size_width, size_width, size_width, size_width, -1 }, 0);

    var ctx_colors = ctx.*.style.*.colors[0..];
    for (colors, 0..) |color, index| {
        microui.drawLabel(color.label);
        _ = uint8Slider(ctx, &ctx_colors[index].r, 0, 255);
        _ = uint8Slider(ctx, &ctx_colors[index].g, 0, 255);
        _ = uint8Slider(ctx, &ctx_colors[index].b, 0, 255);
        _ = uint8Slider(ctx, &ctx_colors[index].a, 0, 255);
        microui.drawRect(c_microui.mu_layout_next(ctx), ctx_colors[index]);
    }
}

fn logWindow(microui: *MicroUI) !void {
    try microui.beginWindow("Log Window", c_microui.mu_rect(350, 40, 300, 200));
    defer microui.endWindow();

    microui.layoutRow(&[_]i32{-1}, -25);
    {
        microui.beginPanel("Log Output");
        defer microui.endPanel();

        const panel = microui.getCurrentContainer();
        if (logbuf.updated) {
            panel.*.scroll.y = panel.*.content_size.y;
            logbuf.updated = true;
        }

        microui.layoutRow(&[_]i32{-1}, -1);
        microui.drawText(&logbuf.buf);
    }

    var buf: [128:0]u8 = undefined;
    buf[0] = 0;
    var submitted: i32 = 0;
    microui.layoutRow(&[_]i32{ -70, -1 }, 0);
    if (microui.drawTextBox(buf[0..128]) & c_microui.MU_RES_SUBMIT != 0) {
        submitted = 1;
    }
    if (microui.drawButton("Submit") != 0) {
        submitted = 1;
    }
    if (submitted != 0) {
        logbuf.write(&buf);
        buf[0] = 0;
    }
}

fn testWindow(ctx: [*c]c_microui.mu_Context, microui: *MicroUI) !void {
    try microui.beginWindow("Test Window", c_microui.mu_rect(40, 40, 300, 450));
    defer microui.endWindow();

    var win = microui.getCurrentContainer();
    win.*.rect.w = c_microui.mu_max(win.*.rect.w, 240);
    win.*.rect.h = c_microui.mu_max(win.*.rect.h, 300);

    // window info
    if (c_microui.mu_header(ctx, "Window Info") != 0) {
        win = microui.getCurrentContainer();
        var buf: [64]u8 = undefined;
        microui.layoutRow(&[_]i32{ 54, -1 }, 0);
        c_microui.mu_label(ctx, "Position:");
        var tmp = std.fmt.bufPrintSentinel(&buf, "{d}, {d}", .{ win.*.rect.x, win.*.rect.y }, 0) catch unreachable;
        c_microui.mu_label(ctx, &tmp[0]);
        c_microui.mu_label(ctx, "Size:");
        tmp = std.fmt.bufPrintSentinel(&buf, "{d}, {d}", .{ win.*.rect.w, win.*.rect.h }, 0) catch unreachable;
        c_microui.mu_label(ctx, &tmp[0]);
    }

    // labels + buttons
    if (c_microui.mu_header_ex(ctx, "Test Buttons", c_microui.MU_OPT_EXPANDED) != 0) {
        microui.layoutRow(&[_]i32{ 140, -110, -1 }, 0);
        c_microui.mu_label(ctx, "Test buttons 1:");
        if (c_microui.mu_button(ctx, "Button 1") != 0) {
            logbuf.write("Pressed button 1");
        }
        if (c_microui.mu_button(ctx, "Button 2") != 0) {
            logbuf.write("Pressed button 2");
        }
        c_microui.mu_label(ctx, "Test buttons 2:");
        if (c_microui.mu_button(ctx, "Button 3") != 0) {
            logbuf.write("Pressed button 3");
        }
        if (c_microui.mu_button(ctx, "Popup") != 0) {
            c_microui.mu_open_popup(ctx, "Test Popup");
        }
        if (c_microui.mu_begin_popup(ctx, "Test Popup") != 0) {
            defer c_microui.mu_end_popup(ctx);

            if (c_microui.mu_button(ctx, "Hello") != 0) {
                logbuf.write("Hello");
            }
            if (c_microui.mu_button(ctx, "World") != 0) {
                logbuf.write("World");
            }
        }
    }

    // tree
    if (c_microui.mu_header_ex(ctx, "Tree and Text", c_microui.MU_OPT_EXPANDED) != 0) {
        microui.layoutRow(&[_]i32{ 160, -1 }, 0);
        {
            c_microui.mu_layout_begin_column(ctx);
            defer c_microui.mu_layout_end_column(ctx);

            if (c_microui.mu_begin_treenode(ctx, "Test 1") != 0) {
                defer c_microui.mu_end_treenode(ctx);

                if (c_microui.mu_begin_treenode(ctx, "Test 1a") != 0) {
                    defer c_microui.mu_end_treenode(ctx);

                    c_microui.mu_label(ctx, "Hello");
                    c_microui.mu_label(ctx, "world");
                }
                if (c_microui.mu_begin_treenode(ctx, "Test 1b") != 0) {
                    defer c_microui.mu_end_treenode(ctx);

                    if (c_microui.mu_button(ctx, "Button 1") != 0) {
                        logbuf.write("Pressed button 1");
                    }
                    if (c_microui.mu_button(ctx, "Button 2") != 0) {
                        logbuf.write("Pressed button 2");
                    }
                }
            }
            if (c_microui.mu_begin_treenode(ctx, "Test 2") != 0) {
                defer c_microui.mu_end_treenode(ctx);

                microui.layoutRow(&[_]i32{ 54, 54 }, 0);
                if (c_microui.mu_button(ctx, "Button 3") != 0) {
                    logbuf.write("Pressed button 3");
                }
                if (c_microui.mu_button(ctx, "Button 4") != 0) {
                    logbuf.write("Pressed button 4");
                }
                if (c_microui.mu_button(ctx, "Button 5") != 0) {
                    logbuf.write("Pressed button 5");
                }
                if (c_microui.mu_button(ctx, "Button 6") != 0) {
                    logbuf.write("Pressed button 6");
                }
            }
            if (c_microui.mu_begin_treenode(ctx, "Test 3") != 0) {
                defer c_microui.mu_end_treenode(ctx);

                _ = c_microui.mu_checkbox(ctx, "Checkbox 1", &checks[0]);
                _ = c_microui.mu_checkbox(ctx, "Checkbox 2", &checks[1]);
                _ = c_microui.mu_checkbox(ctx, "Checkbox 3", &checks[2]);
            }
        }

        {
            c_microui.mu_layout_begin_column(ctx);
            defer c_microui.mu_layout_end_column(ctx);

            microui.layoutRow(&[_]i32{-1}, 0);
            c_microui.mu_text(ctx,
                \\ Lorem ipsum dolor sit amet, consectetur adipiscing elit.
                \\ Maecenas lacinia, sem eu lacinia molestie, 
                \\ mi risus faucibus ipsum, eu varius magna felis a nulla.",
            );
        }
    }

    // background color sliders
    if (c_microui.mu_header_ex(ctx, "Background Color", c_microui.MU_OPT_EXPANDED) != 0) {
        microui.layoutRow(&[_]i32{ -78, -1 }, 74);
        // sliders
        {
            c_microui.mu_layout_begin_column(ctx);
            defer c_microui.mu_layout_end_column(ctx);

            var color: c_microui.mu_Color = .{
                .r = @intFromFloat(bg[0]),
                .g = @intFromFloat(bg[1]),
                .b = @intFromFloat(bg[2]),
                .a = 255,
            };
            defer bg = .{
                @floatFromInt(color.r),
                @floatFromInt(color.g),
                @floatFromInt(color.b),
            };

            microui.layoutRow(&[_]i32{ 60, -1 }, 0);
            c_microui.mu_label(ctx, "Red:");
            _ = uint8Slider(ctx, &color.r, 0, 255);
            c_microui.mu_label(ctx, "Green:");
            _ = uint8Slider(ctx, &color.g, 0, 255);
            c_microui.mu_label(ctx, "Blue:");
            _ = uint8Slider(ctx, &color.b, 0, 255);
        }
        // color preview
        const rect = c_microui.mu_layout_next(ctx);
        const color: c_microui.mu_Color = .{
            .r = @intFromFloat(bg[0]),
            .g = @intFromFloat(bg[1]),
            .b = @intFromFloat(bg[2]),
            .a = 255,
        };
        microui.drawRect(rect, color);
        var buf: [32]u8 = undefined;
        const view = std.fmt.bufPrintSentinel(&buf, "#{x:02}{x:02}{x:02}", .{ color.r, color.g, color.b }, 0) catch unreachable;
        c_microui.mu_draw_control_text(ctx, view[0..], rect, c_microui.MU_COLOR_TEXT, c_microui.MU_OPT_ALIGNCENTER);
    }
}

fn processFrame(ctx: [*c]c_microui.mu_Context, microui: *MicroUI) !void {
    c_microui.mu_begin(ctx);
    defer c_microui.mu_end(ctx);

    try styleWindow(ctx, microui);
    try logWindow(microui);
    try testWindow(ctx, microui);
}

pub fn main(init: std.process.Init) !void {
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

    const ctx = try allocator.create(c_microui.mu_Context);
    defer allocator.destroy(ctx);

    c_microui.mu_init(ctx);
    ctx.*.text_width = textWidth;
    ctx.*.text_height = textHeight;

    var microui = MicroUI.init(ctx);

    // Main loop
    var is_running = true;
    while (is_running) {
        var event: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&event)) {
            switch (event.type) {
                sdl.SDL_EVENT_QUIT => is_running = false,
                sdl.SDL_EVENT_MOUSE_MOTION => c_microui.mu_input_mousemove(
                    ctx,
                    @as(c_int, @intFromFloat(event.motion.x)),
                    @as(c_int, @intFromFloat(event.motion.y)),
                ),
                sdl.SDL_EVENT_MOUSE_WHEEL => c_microui.mu_input_scroll(
                    ctx,
                    0,
                    @as(c_int, @intFromFloat(event.wheel.y * -30)),
                ),
                sdl.SDL_EVENT_TEXT_INPUT => c_microui.mu_input_text(ctx, event.text.text),
                sdl.SDL_EVENT_MOUSE_BUTTON_DOWN, sdl.SDL_EVENT_MOUSE_BUTTON_UP => {
                    const btn = button_map[event.button.button & 0xff];
                    if (btn != 0 and event.type == sdl.SDL_EVENT_MOUSE_BUTTON_DOWN) {
                        c_microui.mu_input_mousedown(
                            ctx,
                            @as(c_int, @intFromFloat(event.button.x)),
                            @as(c_int, @intFromFloat(event.button.y)),
                            btn,
                        );
                    }
                    if (btn != 0 and event.type == sdl.SDL_EVENT_MOUSE_BUTTON_UP) {
                        c_microui.mu_input_mouseup(
                            ctx,
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
                        std.debug.print("Key down\n", .{});
                        c_microui.mu_input_keydown(ctx, key);
                    }
                    if (key != 0 and event.type == sdl.SDL_EVENT_KEY_UP) {
                        std.debug.print("Key up\n", .{});
                        c_microui.mu_input_keyup(ctx, key);
                    }
                },
                else => {},
            }
        }

        try processFrame(ctx, &microui);

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

        var cmd: [*c]c_microui.mu_Command = null;
        while (c_microui.mu_next_command(ctx, &cmd) != 0) {
            const cmd_type = cmd.*.type;
            if (cmd_type == c_microui.MU_COMMAND_TEXT) {
                var s: [:0]u8 = @ptrCast(&(cmd.*.text.str[0]));
                var p: [*c]u8 = &(cmd.*.text.str[0]);
                while (p.* != 0) : (p += 1) {
                    s.len += 1;
                }
                s.len -= 1;
                const rect = cmd.*.text.pos;
                render_engine.drawText(s, math.vec.Vec2(f32).init(
                    @as(f32, @floatFromInt(rect.x)),
                    @as(f32, @floatFromInt(rect.y)),
                )) catch {};
            } else if (cmd_type == c_microui.MU_COMMAND_RECT) {
                const rect = cmd.*.rect;
                const color = cmd.*.rect.color;
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
            } else if (cmd_type == c_microui.MU_COMMAND_ICON) {
                const rect = cmd.*.icon.rect;
                const id: usize = @intCast(cmd.*.icon.id);
                render_engine.drawIcon(id, math.rect.Rect2(f32).init(
                    @as(f32, @floatFromInt(rect.x)),
                    @as(f32, @floatFromInt(rect.y)),
                    @as(f32, @floatFromInt(rect.w)),
                    @as(f32, @floatFromInt(rect.h)),
                )) catch {};
            } else if (cmd_type == c_microui.MU_COMMAND_CLIP) {
                const rect = cmd.*.clip.rect;
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
