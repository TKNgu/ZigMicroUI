const std = @import("std");
pub const sdl = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3_image/SDL_image.h");
    @cInclude("SDL3_ttf/SDL_ttf.h");
});
const math = @import("math.zig");
const color = @import("color.zig");

pub const Window = struct {
    window: *sdl.SDL_Window,

    pub fn init(title: [:0]const u8, width: i32, height: i32) !Window {
        const window = sdl.SDL_CreateWindow(title, width, height, sdl.SDL_WINDOW_VULKAN);
        if (window == null) {
            return error.SDLCreateWindowFailed;
        }
        return .{
            .window = window.?,
        };
    }

    pub fn deinit(self: *Window) void {
        sdl.SDL_DestroyWindow(self.window);
    }
};

pub const Renderer = struct {
    renderer: *sdl.SDL_Renderer,

    pub fn init(window: *Window) !Renderer {
        const renderer = sdl.SDL_CreateRenderer(window.window, null);
        if (renderer == null) {
            return error.SDLCreateRendererFailed;
        }
        errdefer sdl.SDL_DestroyRenderer(renderer);

        if (sdl.SDL_RenderClipEnabled(renderer)) {
            return error.SDLRenderClipEnabledFailed;
        }
        return .{
            .renderer = renderer.?,
        };
    }

    pub fn deinit(self: *Renderer) void {
        sdl.SDL_DestroyRenderer(self.renderer);
    }

    pub fn clear(self: *Renderer, r: u8, g: u8, b: u8, a: u8) bool {
        return sdl.SDL_SetRenderDrawColor(self.renderer, r, g, b, a) and
            sdl.SDL_RenderClear(self.renderer);
    }

    pub fn present(self: *Renderer) bool {
        return sdl.SDL_RenderPresent(self.renderer);
    }

    pub fn clip(self: *Renderer, rect: math.rect.Rect2(f32)) bool {
        const sdl_rect = sdl.SDL_Rect{
            .x = @intFromFloat(std.math.floor(rect.pos.x)),
            .y = @intFromFloat(std.math.floor(rect.pos.y)),
            .w = @intFromFloat(std.math.floor(rect.size.x + 1)),
            .h = @intFromFloat(std.math.floor(rect.size.y + 1)),
        };
        return sdl.SDL_SetRenderClipRect(self.renderer, &sdl_rect);
    }
};

pub const Texture = struct {
    texture: *sdl.SDL_Texture,

    pub fn init_from_surface(surface: *sdl.SDL_Surface, renderer: *Renderer) !Texture {
        const texture = sdl.SDL_CreateTextureFromSurface(renderer.renderer, surface);
        if (texture == null) {
            return error.SDLCreateTextureFromSurfaceFailed;
        }
        return .{
            .texture = texture.?,
        };
    }

    pub fn deinit(self: *Texture) void {
        sdl.SDL_DestroyTexture(self.texture);
    }

    pub fn render(
        self: *Texture,
        renderer: *Renderer,
        src_rect: ?math.rect.Rect2(f32),
        dst_rect: ?math.rect.Rect2(f32),
    ) !void {
        var tmp_src_rect: sdl.SDL_FRect = undefined;
        const csrc_rect = if (src_rect) |src| RECT: {
            tmp_src_rect = .{
                .x = src.pos.x,
                .y = src.pos.y,
                .w = src.size.x,
                .h = src.size.y,
            };
            break :RECT &tmp_src_rect;
        } else null;

        var tmp_dst_rect: sdl.SDL_FRect = undefined;
        const cdst_rect = if (dst_rect) |dst| RECT: {
            tmp_dst_rect = .{
                .x = dst.pos.x,
                .y = dst.pos.y,
                .w = dst.size.x,
                .h = dst.size.y,
            };
            break :RECT &tmp_dst_rect;
        } else null;

        if (!sdl.SDL_RenderTexture(
            renderer.renderer,
            self.texture,
            csrc_rect,
            cdst_rect,
        )) {
            return error.RenderError;
        }
    }
};

pub const Font = struct {
    font: *sdl.TTF_Font,

    pub fn init(font_path: [:0]const u8, size: f32) !Font {
        const font = sdl.TTF_OpenFont(font_path, size);
        if (font == null) {
            return error.TTFOpenFontFailed;
        }
        return .{
            .font = font.?,
        };
    }

    pub fn deinit(self: *Font) void {
        sdl.TTF_CloseFont(self.font);
    }

    pub fn renderTextSurface(
        self: *Font,
        text: [:0]const u8,
        text_color: color.Color,
    ) ![*c]sdl.SDL_Surface {
        const surface = sdl.TTF_RenderText_Blended(self.font, text, text.len, .{
            .r = text_color.r,
            .g = text_color.g,
            .b = text_color.b,
            .a = text_color.a,
        });
        return if (surface == null) error.TTFRenderTextFailed else surface.?;
    }

    pub fn renderTextTexture(
        self: *Font,
        text: [:0]const u8,
        text_color: color.Color,
        renderer: *Renderer,
    ) !struct { texture: Texture, size: math.vec.Vec2(c_int) } {
        const surface = try self.renderTextSurface(text, text_color);
        defer sdl.SDL_DestroySurface(surface);
        const texture = try Texture.init_from_surface(surface, renderer);
        return .{ .texture = texture, .size = .{ .x = surface.*.w, .y = surface.*.h } };
    }
};
