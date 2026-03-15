const std = @import("std");
const sdl = @import("sdl.zig").sdl;
const microui = @cImport({
    @cInclude("microui.h");
});
const atlas = @cImport({
    @cInclude("atlas.h");
});

fn textWidth(_: ?*anyopaque, _: [*c]const u8, _: c_int) callconv(.c) c_int {
    return 0;
}

fn textHeight(_: ?*anyopaque) callconv(.c) c_int {
    return 0;
}

pub fn main() !void {
    var ctx: microui.mu_Context = undefined;
    microui.mu_init(&ctx);
    ctx.text_width = textWidth;
    ctx.text_height = textHeight;

    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
        return error.SDLInitFailed;
    }
    defer sdl.SDL_Quit();

    var windowOption: ?*sdl.SDL_Window = null;
    var rendererOption: ?*sdl.SDL_Renderer = null;
    if (!sdl.SDL_CreateWindowAndRenderer(
        "ZigUI",
        800,
        640,
        sdl.SDL_WINDOW_VULKAN,
        &windowOption,
        &rendererOption,
    )) {
        return error.SDLCreateWindowAndRendererFailed;
    }

    const window = windowOption.?;
    const renderer = rendererOption.?;
    defer sdl.SDL_DestroyWindow(window);
    defer sdl.SDL_DestroyRenderer(renderer);

    var texture: [atlas.ATLAS_WIDTH * atlas.ATLAS_HEIGHT * 4]u8 = undefined;
    for (0..atlas.ATLAS_HEIGHT) |y| {
        const offset = y * atlas.ATLAS_WIDTH * 4;
        const atlasOffset = y * atlas.ATLAS_WIDTH;
        for (0..atlas.ATLAS_WIDTH) |x| {
            const index = offset + x * 4;
            texture[index + 0] = 0xff;
            texture[index + 1] = 0xff;
            texture[index + 2] = 0xff;
            texture[index + 3] = atlas.atlas_texture[atlasOffset + x];
        }
    }
    const surface = sdl.SDL_CreateSurfaceFrom(
        atlas.ATLAS_WIDTH,
        atlas.ATLAS_HEIGHT,
        sdl.SDL_PIXELFORMAT_RGBA32,
        &texture,
        atlas.ATLAS_WIDTH * 4,
    );
    const iconOption = sdl.SDL_CreateTextureFromSurface(renderer, surface);
    const icon = iconOption orelse return error.SDLCreateIconTextureFailed;

    var isRunning = true;
    while (isRunning) {
        var event: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&event)) {
            switch (event.type) {
                sdl.SDL_EVENT_QUIT => isRunning = false,
                sdl.SDL_EVENT_MOUSE_MOTION => microui.mu_input_mousemove(
                    &ctx,
                    @intFromFloat(event.motion.x),
                    @intFromFloat(event.motion.y),
                ),
                sdl.SDL_EVENT_MOUSE_BUTTON_DOWN, sdl.SDL_EVENT_MOUSE_BUTTON_UP => {
                    const b = switch (event.button.button) {
                        sdl.SDL_BUTTON_LEFT => microui.MU_MOUSE_LEFT,
                        sdl.SDL_BUTTON_RIGHT => microui.MU_MOUSE_RIGHT,
                        sdl.SDL_BUTTON_MIDDLE => microui.MU_MOUSE_MIDDLE,
                        else => 0,
                    };
                    const x: i32 = @intFromFloat(event.motion.x);
                    const y: i32 = @intFromFloat(event.motion.y);
                    if (b != 0 and event.type == sdl.SDL_EVENT_MOUSE_BUTTON_DOWN) {
                        microui.mu_input_mousedown(&ctx, x, y, b);
                    }
                    if (b != 0 and event.type == sdl.SDL_EVENT_MOUSE_BUTTON_UP) {
                        microui.mu_input_mouseup(&ctx, x, y, b);
                    }
                },
                else => {},
            }
        }

        microui.mu_begin(&ctx);
        const windowRect = microui.mu_rect(350, 250, 300, 240);
        if (microui.mu_begin_window(&ctx, "View", windowRect) != 0) {
            const layour = [_]c_int{-1};
            microui.mu_layout_row(&ctx, 1, &layour, -25);
            microui.mu_begin_panel(&ctx, "Log Output");
            _ = microui.mu_get_current_container(&ctx);
            microui.mu_layout_row(&ctx, 1, &layour, -1);
            microui.mu_label(&ctx, "Blue:");
            // microui.mu_text(&ctx, logbuf);
            microui.mu_end_panel(&ctx);
            // if (logbuf_updated) {
            //   panel->scroll.y = panel->content_size.y;
            //   logbuf_updated = 0;
            // }
            //
            // /* input textbox + submit button */
            // static char buf[128];
            // int submitted = 0;
            // mu_layout_row(ctx, 2, (int[]){-70, -1}, 0);
            // if (mu_textbox(ctx, buf, sizeof(buf)) & MU_RES_SUBMIT) {
            //   mu_set_focus(ctx, ctx->last_id);
            //   submitted = 1;
            // }
            // if (mu_button(ctx, "Submit")) {
            //   submitted = 1;
            // }
            // if (submitted) {
            //   write_log(buf);
            //   buf[0] = '\0';
            // }

            microui.mu_end_window(&ctx);
        }
        microui.mu_end(&ctx);

        if (!sdl.SDL_SetRenderDrawColor(renderer, 128, 128, 128, 255)) {
            isRunning = false;
            continue;
        }
        if (!sdl.SDL_RenderClear(renderer)) {
            isRunning = false;
            continue;
        }

        if (!sdl.SDL_RenderTexture(renderer, icon, null, null)) {
            isRunning = false;
            continue;
        }

        var cmd: [*c]microui.mu_Command = 0;
        while (microui.mu_next_command(&ctx, &cmd) != 0) {
            const cmdType = cmd.*;
            if (cmdType.type == microui.MU_COMMAND_RECT) {
                const rect = cmdType.rect;
                const color = rect.color;
                if (!sdl.SDL_SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a)) {
                    isRunning = false;
                    continue;
                }
                const sdlRect = sdl.SDL_FRect{
                    .x = @floatFromInt(rect.rect.x),
                    .y = @floatFromInt(rect.rect.y),
                    .w = @floatFromInt(rect.rect.w),
                    .h = @floatFromInt(rect.rect.h),
                };
                if (!sdl.SDL_RenderFillRect(renderer, &sdlRect)) {
                    isRunning = false;
                    continue;
                }
            } else if (cmdType.type == microui.MU_COMMAND_RECT) {
                const rect = cmdType.clip.rect;
                const sdlRect = sdl.SDL_Rect{
                    .x = rect.x,
                    .y = rect.y,
                    .w = rect.w,
                    .h = rect.h,
                };
                if (!sdl.SDL_SetRenderClipRect(renderer, &sdlRect)) {
                    isRunning = false;
                    continue;
                }
            } else if (cmdType.type == microui.MU_COMMAND_ICON) {
                const id = cmdType.icon.id;
                const rect = cmdType.icon.rect;
                // const color = cmdType.icon.color;
                const src = atlas.atlas[@intCast(id)];

                const srcRect = sdl.SDL_FRect{
                    .x = @floatFromInt(src.x),
                    .y = @floatFromInt(src.y),
                    .h = @floatFromInt(src.h),
                    .w = @floatFromInt(src.w),
                };

                const sdlRect = sdl.SDL_FRect{
                    .x = @floatFromInt(rect.x),
                    .y = @floatFromInt(rect.y),
                    .w = @floatFromInt(rect.w),
                    .h = @floatFromInt(rect.h),
                };
                if (!sdl.SDL_RenderTexture(renderer, icon, &srcRect, &sdlRect)) {
                    isRunning = false;
                    continue;
                }
            } else if (cmdType.type == microui.MU_COMMAND_TEXT) {
                const pos = cmdType.text.pos;
                var dst = sdl.SDL_FRect{
                    .x = @floatFromInt(pos.x),
                    .y = @floatFromInt(pos.y),
                    .w = 0,
                    .h = 0,
                };
                for (cmdType.text.str) |chr| {
                    if ((chr & 0xc0) == 0x80) {
                        continue;
                    }
                    const index = if (chr < 127)
                        @as(usize, chr)
                    else
                        127;
                    const src = atlas.atlas[atlas.ATLAS_FONT + index];
                    const sdlRect = sdl.SDL_FRect{
                        .x = @floatFromInt(src.x),
                        .y = @floatFromInt(src.y),
                        .w = @floatFromInt(src.w),
                        .h = @floatFromInt(src.h),
                    };
                    dst.w = sdlRect.w;
                    dst.h = sdlRect.h;
                    if (!sdl.SDL_RenderTexture(renderer, icon, &sdlRect, &dst)) {
                        isRunning = false;
                        continue;
                    }
                }
            } else if (cmdType.type == microui.MU_COMMAND_ICON) {
                const src = atlas.atlas[@intCast(atlas.ATLAS_FONT + cmdType.icon.id)];
                const rect = cmdType.icon.rect;
                const x = @as(f32, @floatFromInt(rect.x)) +
                    @as(f32, @floatFromInt(rect.w - src.w)) / 2;
                const y = @as(f32, @floatFromInt(rect.y)) +
                    @as(f32, @floatFromInt(rect.h - src.h)) / 2;

                const sdlSrc = sdl.SDL_FRect{
                    .x = @floatFromInt(src.x),
                    .y = @floatFromInt(src.y),
                    .w = @floatFromInt(src.w),
                    .h = @floatFromInt(src.h),
                };
                const sdlDst = sdl.SDL_FRect{
                    .x = x,
                    .y = y,
                    .w = @floatFromInt(src.w),
                    .h = @floatFromInt(src.h),
                };

                if (!sdl.SDL_RenderTexture(renderer, icon, &sdlSrc, &sdlDst)) {
                    isRunning = false;
                    continue;
                }
            }
        }

        if (!sdl.SDL_RenderPresent(renderer)) {
            isRunning = false;
            continue;
        }

        sdl.SDL_Delay(16);
    }
}
