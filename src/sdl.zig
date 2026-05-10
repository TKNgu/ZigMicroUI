pub const sdl = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3_image/SDL_image.h");
    @cInclude("SDL3_ttf/SDL_ttf.h");
});
const math = @import("math.zig");
const Color = @import("color.zig").Color;

pub const Window = struct {
    window: *sdl.SDL_Window,

    pub fn init(title: [:0]const u8, size: math.vec.Vec2(i32)) !Window {
        const window = sdl.SDL_CreateWindow(title, size.x, size.y, sdl.SDL_WINDOW_VULKAN);
        if (window == null) {
            return error.SDLCreateWindowFailed;
        }
        return Window{
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
        return Renderer{
            .renderer = renderer.?,
        };
    }

    pub fn deinit(self: *Renderer) void {
        sdl.SDL_DestroyRenderer(self.renderer);
    }

    pub fn clear(self: *Renderer, clear_color: Color) bool {
        return sdl.SDL_SetRenderDrawColor(
            self.renderer,
            clear_color.r,
            clear_color.g,
            clear_color.b,
            clear_color.a,
        ) and
            sdl.SDL_RenderClear(self.renderer);
    }

    pub fn present(self: *Renderer) bool {
        return sdl.SDL_RenderPresent(self.renderer);
    }
};

pub const draw = struct {
    pub fn rect(renderer: *Renderer, rect_draw: math.rect.Rect2(f32), color: Color) !void {
        if (!sdl.SDL_SetRenderDrawColor(renderer.renderer, color.r, color.g, color.b, color.a)) {
            return error.RenderErrorSetColor;
        }
        const sdlRect = sdl.SDL_FRect{
            .x = rect_draw.pos.x,
            .y = rect_draw.pos.y,
            .w = rect_draw.size.x,
            .h = rect_draw.size.y,
        };
        if (!sdl.SDL_RenderRect(renderer.renderer, &sdlRect)) {
            return error.RenderError;
        }
    }

    pub fn fillRect(renderer: *Renderer, rect_draw: math.rect.Rect2(f32), color: Color) !void {
        if (!sdl.SDL_SetRenderDrawColor(renderer.renderer, color.r, color.g, color.b, color.a)) {
            return error.RenderErrorSetColor;
        }
        const sdlRect = sdl.SDL_FRect{
            .x = rect_draw.pos.x,
            .y = rect_draw.pos.y,
            .w = rect_draw.size.x,
            .h = rect_draw.size.y,
        };
        if (!sdl.SDL_RenderFillRect(renderer.renderer, &sdlRect)) {
            return error.RenderError;
        }
    }
};
