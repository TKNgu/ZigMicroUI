pub const sdl = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3_image/SDL_image.h");
    @cInclude("SDL3_ttf/SDL_ttf.h");
});
const math = @import("math.zig");
const Color = @import("color.zig").Color;
const std = @import("std");

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

pub const DrawEngine = struct {
    pub const Rect = struct {
        rect_draw: math.rect.Rect2(f32),
        color: Color,
    };
    pub const FillRect = struct {
        rect_draw: math.rect.Rect2(f32),
        color: Color,
    };
    const DrawCommand = union(enum) {
        Rect: Rect,
        FillRect: FillRect,
    };

    background: Color,
    draw_commands: [1024]DrawCommand,
    idx: usize,

    pub fn init(background: Color) DrawEngine {
        return DrawEngine{
            .background = background,
            .draw_commands = undefined,
            .idx = 0,
        };
    }

    pub fn reset(self: *DrawEngine) void {
        self.*.idx = 0;
    }

    pub fn push(self: *DrawEngine, cmd: DrawCommand) !void {
        if (self.*.idx >= self.*.draw_commands.len) {
            return error.DrawEngineFull;
        }
        self.*.draw_commands[self.*.idx] = cmd;
        self.*.idx += 1;
    }

    pub fn render(self: *DrawEngine, renderer: *Renderer) !void {
        if (!renderer.clear(self.*.background)) {
            return error.RenderError;
        }
        var idx: usize = 0;
        while (idx < self.*.idx) : (idx += 1) {
            switch (self.*.draw_commands[idx]) {
                .Rect => |cmd| {
                    try draw.rect(renderer, cmd.rect_draw, cmd.color);
                },
                .FillRect => |cmd| {
                    try draw.fillRect(renderer, cmd.rect_draw, cmd.color);
                },
            }
        }
        if (!renderer.present()) {
            return error.RenderError;
        }
    }
};
