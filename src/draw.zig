const sdl = @import("sdl.zig").sdl;
const microui = @import("sdl.zig").microui;
const atlas = @import("sdl.zig").atlas;

pub fn loadAtlas(renderer: *sdl.SDL_Renderer) !*sdl.SDL_Texture {
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
    sdl.SDL_DestroySurface(surface);
    const icon = iconOption orelse return error.SDLCreateIconTextureFailed;
    if (icon != null) {
        return icon;
    } else {
        return error.TextureError;
    }
}

pub fn clear(renderer: *sdl.SDL_Renderer) !void {
    if (!sdl.SDL_SetRenderDrawColor(renderer, 128, 128, 128, 255)) {
        return error.ErrorRendere;
    }
    if (!sdl.SDL_RenderClear(renderer)) {
        return error.ErrorRendere;
    }
}

pub fn textWidth(_: ?*anyopaque, _: [*c]const u8, _: c_int) callconv(.c) c_int {
    return 0;
}

pub fn textHeight(_: ?*anyopaque) callconv(.c) c_int {
    return 0;
}

pub fn drawRect(renderer: *sdl.SDL_Renderer, cmd: microui.mu_Command) !void {
    const rect = cmd.rect;
    const color = rect.color;
    if (!sdl.SDL_SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a)) {
        return error.RenderError;
    }
    const sdlRect = sdl.SDL_FRect{
        .x = @floatFromInt(rect.rect.x),
        .y = @floatFromInt(rect.rect.y),
        .w = @floatFromInt(rect.rect.w),
        .h = @floatFromInt(rect.rect.h),
    };
    if (!sdl.SDL_RenderFillRect(renderer, &sdlRect)) {
        return error.RenderError;
    }
}

pub fn clipRect(renderer: *sdl.SDL_Renderer, cmd: microui.mu_Command) !void {
    const rect = cmd.clip.rect;
    const sdlRect = sdl.SDL_Rect{
        .x = rect.x,
        .y = rect.y,
        .w = rect.w,
        .h = rect.h,
    };
    if (!sdl.SDL_SetRenderClipRect(renderer, &sdlRect)) {
        return error.RenderError;
    }
}

pub fn drawIcon(
    renderer: *sdl.SDL_Renderer,
    cmd: microui.mu_Command,
    icon: *sdl.SDL_Texture,
) !void {
    const id = cmd.icon.id;
    const rect = cmd.icon.rect;
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
        return error.RenderError;
    }
}

pub fn drawText(
    renderer: *sdl.SDL_Renderer,
    cmd: microui.mu_Command,
    icon: *sdl.SDL_Texture,
) !void {
    const pos = cmd.text.pos;
    var dst = sdl.SDL_FRect{
        .x = @floatFromInt(pos.x),
        .y = @floatFromInt(pos.y),
        .w = 0,
        .h = 0,
    };
    for (cmd.text.str) |chr| {
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
            return error.RenderError;
        }
    }
}
