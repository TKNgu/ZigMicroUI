const std = @import("std");
const math = @import("math.zig");
const sdl = @import("sdl.zig");
const csdl = sdl.csdl;
const color = @import("color.zig");
const atlas = @import("atlas.zig");

pub const RenderEngine = struct {
    renderer: *sdl.Renderer,

    pub fn init(renderer: *sdl.Renderer) !RenderEngine {
        return .{
            .renderer = renderer,
        };
    }

    fn loadTexture(
        renderer: *csdl.SDL_Renderer,
        allocator: std.mem.Allocator,
    ) !*csdl.SDL_Texture {
        const bitmap = try atlas.getBitmap(allocator);
        defer allocator.free(bitmap);

        const surface = csdl.SDL_CreateSurfaceFrom(
            atlas.ATLAS_WIDTH,
            atlas.ATLAS_HEIGHT,
            csdl.SDL_PIXELFORMAT_RGB24,
            @ptrCast(@constCast(bitmap)),
            atlas.ATLAS_WIDTH * 3,
        );
        if (surface == null) {
            const tmp: [*c]const u8 = csdl.SDL_GetError();
            std.debug.print("SDL_CreateSurfaceFrom failed: {s}\n", .{tmp});
            return error.SDLCreateSurfaceFromFailed;
        }
        defer csdl.SDL_DestroySurface(surface);

        const texture = csdl.SDL_CreateTextureFromSurface(renderer, surface);
        if (texture == null) {
            const tmp: [*c]const u8 = csdl.SDL_GetError();
            std.debug.print("SDL_CreateTextureFromSurface failed: {s}\n", .{tmp});
            return error.SDLCreateTextureFromSurfaceFailed;
        }
        return texture;
    }

    pub fn rect(self: *RenderEngine, rect_draw: math.rect.Rect2(f32), draw_color: color.Color) !void {
        if (!csdl.SDL_SetRenderDrawColor(
            self.renderer.renderer,
            draw_color.r,
            draw_color.g,
            draw_color.b,
            draw_color.a,
        )) {
            return error.RenderErrorSetColor;
        }
        const sdlRect = csdl.SDL_FRect{
            .x = rect_draw.getX(),
            .y = rect_draw.getY(),
            .w = rect_draw.getWidth(),
            .h = rect_draw.getHeight(),
        };
        if (!csdl.SDL_RenderRect(self.renderer.renderer, &sdlRect)) {
            return error.RenderError;
        }
    }

    pub fn fillRect(self: *RenderEngine, rect_draw: math.rect.Rect2(f32), draw_color: color.Color) !void {
        if (!csdl.SDL_SetRenderDrawColor(
            self.renderer.renderer,
            draw_color.r,
            draw_color.g,
            draw_color.b,
            draw_color.a,
        )) {
            return error.RenderErrorSetColor;
        }
        const sdlRect = csdl.SDL_FRect{
            .x = rect_draw.getX(),
            .y = rect_draw.getY(),
            .w = rect_draw.getWidth(),
            .h = rect_draw.getHeight(),
        };
        if (!csdl.SDL_RenderFillRect(self.renderer.renderer, &sdlRect)) {
            return error.RenderError;
        }
    }

    pub fn drawLine(self: *RenderEngine, start_point: math.vec.Vec2(f32), end_point: math.vec.Vec2(f32), draw_color: color.Color) !void {
        if (!csdl.SDL_SetRenderDrawColor(
            self.renderer.renderer,
            draw_color.r,
            draw_color.g,
            draw_color.b,
            draw_color.a,
        )) {
            return error.RenderErrorSetColor;
        }
        if (!csdl.SDL_RenderLine(self.renderer.renderer, start_point.x, start_point.y, end_point.x, end_point.y)) {
            return error.RenderError;
        }
    }

    pub fn drawTextureTest(self: *RenderEngine) !void {
        const dst_rect: csdl.SDL_FRect = .{
            .x = 0,
            .y = 0,
            .w = atlas.ATLAS_WIDTH,
            .h = atlas.ATLAS_HEIGHT,
        };
        if (!csdl.SDL_RenderTexture(self.renderer.renderer, self.texture, null, &dst_rect)) {
            return error.RenderError;
        }
    }

    pub fn drawTexture(
        self: *RenderEngine,
        texture: *csdl.SDL_Texture,
        src_rect: ?math.rect.Rect2(f32),
        dst_rect: ?math.rect.Rect2(f32),
    ) !void {
        var tmp_src_rect: csdl.SDL_FRect = undefined;
        const csrc_rect = if (src_rect) |src| RECT: {
            tmp_src_rect = .{
                .x = src.pos.x,
                .y = src.pos.y,
                .w = src.size.x,
                .h = src.size.y,
            };
            break :RECT &tmp_src_rect;
        } else null;

        var tmp_dst_rect: csdl.SDL_FRect = undefined;
        const cdst_rect = if (dst_rect) |dst| RECT: {
            tmp_dst_rect = .{
                .x = dst.pos.x,
                .y = dst.pos.y,
                .w = dst.size.x,
                .h = dst.size.y,
            };
            break :RECT &tmp_dst_rect;
        } else null;

        if (!csdl.SDL_RenderTexture(
            self.renderer.renderer,
            texture,
            csrc_rect,
            cdst_rect,
        )) {
            return error.RenderError;
        }
    }

    pub fn drawText(
        self: *RenderEngine,
        start_location: math.vec.Vec2(f32),
        table: []const math.rect.Rect2(f32),
        text: []const u8,
    ) !void {
        var char_location = start_location;
        for (text) |c| {
            const text_rect = table[c];
            try self.drawTexture(
                text_rect,
                math.rect.Rect2(f32).init(
                    char_location.x,
                    char_location.y,
                    text_rect.getWidth(),
                    text_rect.getHeight(),
                ),
            );
            char_location.x += text_rect.getWidth();
        }
    }
};
