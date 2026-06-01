const math = @import("math.zig");
const sdl = @import("sdl.zig");
const csdl = sdl.csdl;
const color = @import("color.zig");

pub const RenderEngine = struct {
    renderer: *sdl.Renderer,

    pub fn init(renderer: *sdl.Renderer) RenderEngine {
        return .{
            .renderer = renderer,
        };
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
};
