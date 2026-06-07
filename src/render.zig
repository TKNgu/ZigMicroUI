const std = @import("std");
const math = @import("math.zig");
const sdl = @import("sdl.zig");
const csdl = sdl.csdl;
const color = @import("color.zig");
const atlas = @import("atlas.zig");

pub const RenderEngine = struct {
    renderer: *sdl.Renderer,
    texture: *csdl.SDL_Texture,

    pub fn init(renderer: *sdl.Renderer, allocator: std.mem.Allocator) !RenderEngine {
        const texture = try loadTexture(renderer.renderer, allocator);
        return .{
            .renderer = renderer,
            .texture = texture,
        };
    }

    pub fn deinit(self: *RenderEngine) void {
        csdl.SDL_DestroyTexture(self.texture);
    }

    fn loadTexture(
        renderer: *csdl.SDL_Renderer,
        allocator: std.mem.Allocator,
    ) !*csdl.SDL_Texture {
        const bitmap = try allocator.alloc(u8, atlas.ATLAS_WIDTH * atlas.ATLAS_HEIGHT * 4);
        defer allocator.free(bitmap);
        for (0..atlas.ATLAS_WIDTH) |x| {
            for (0..atlas.ATLAS_HEIGHT) |y| {
                const index = y * atlas.ATLAS_WIDTH + x;
                const value = atlas.ATLAS_TEXTURE[index];
                if (value != 0) {
                    bitmap[index * 4 + 0] = 255;
                    bitmap[index * 4 + 1] = 255;
                    bitmap[index * 4 + 2] = 255;
                } else {
                    bitmap[index * 4 + 0] = 0;
                    bitmap[index * 4 + 1] = 0;
                    bitmap[index * 4 + 2] = 0;
                }
                bitmap[index * 4 + 3] = 255;
            }
        }

        const surface = csdl.SDL_CreateSurfaceFrom(
            atlas.ATLAS_WIDTH,
            atlas.ATLAS_HEIGHT,
            csdl.SDL_PIXELFORMAT_RGBA8888,
            @ptrCast(@constCast(bitmap)),
            atlas.ATLAS_WIDTH * 4,
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
        var dst_rect: csdl.SDL_FRect = .{
            .x = 0,
            .y = 0,
            .w = atlas.ATLAS_WIDTH,
            .h = atlas.ATLAS_HEIGHT,
        };
        if (!csdl.SDL_RenderTexture(self.renderer.renderer, self.texture, null, &dst_rect)) {
            return error.RenderError;
        }
    }
};
