const std = @import("std");
const math = @import("math.zig");
const sdl = @import("sdl.zig").sdl;
const Renderer = @import("sdl.zig").Renderer;
const Font = @import("sdl.zig").Font;
const Texture = @import("sdl.zig").Texture;
const color = @import("color.zig");
const atlas = @import("atlas.zig");

pub const RenderEngine = struct {
    renderer: *Renderer,
    font_ui: Font,
    font_color: color.Color,
    font_atlas: atlas.FontAtlas,
    texture: Texture,

    pub fn init(
        allocator: std.mem.Allocator,
        renderer: *Renderer,
        font_path: [:0]const u8,
        size: f32,
        font_color: color.Color,
    ) !RenderEngine {
        var font_ui = try Font.init(font_path, size);
        const font_atlas = try atlas.FontAtlas.init(&font_ui, font_color, renderer);

        const texture = try loadTexture(allocator, renderer.renderer);
        errdefer sdl.SDL_DestroyTexture(texture);

        return .{
            .renderer = renderer,
            .font_ui = font_ui,
            .font_color = font_color,
            .font_atlas = font_atlas,
            .texture = .{
                .texture = texture,
            },
        };
    }

    pub fn deinit(self: *RenderEngine) void {
        self.font_ui.deinit();
        self.font_atlas.deinit();
        self.texture.deinit();
    }

    fn loadTexture(
        allocator: std.mem.Allocator,
        renderer: *sdl.SDL_Renderer,
    ) !*sdl.SDL_Texture {
        const bitmap = try atlas.getBitmap(allocator);
        defer allocator.free(bitmap);

        const surface = sdl.SDL_CreateSurfaceFrom(
            atlas.ATLAS_WIDTH,
            atlas.ATLAS_HEIGHT,
            sdl.SDL_PIXELFORMAT_RGB24,
            @ptrCast(@constCast(bitmap)),
            atlas.ATLAS_WIDTH * 3,
        );
        if (surface == null) {
            const tmp: [*c]const u8 = sdl.SDL_GetError();
            std.debug.print("SDL_CreateSurfaceFrom failed: {s}\n", .{tmp});
            return error.SDLCreateSurfaceFromFailed;
        }
        defer sdl.SDL_DestroySurface(surface);

        const texture = sdl.SDL_CreateTextureFromSurface(renderer, surface);
        if (texture == null) {
            const tmp: [*c]const u8 = sdl.SDL_GetError();
            std.debug.print("SDL_CreateTextureFromSurface failed: {s}\n", .{tmp});
            return error.SDLCreateTextureFromSurfaceFailed;
        }
        return texture;
    }

    pub fn rect(self: *RenderEngine, rect_draw: math.rect.Rect2(f32), draw_color: color.Color) !void {
        if (!sdl.SDL_SetRenderDrawColor(
            self.renderer.renderer,
            draw_color.r,
            draw_color.g,
            draw_color.b,
            draw_color.a,
        )) {
            return error.RenderErrorSetColor;
        }
        const sdlRect = sdl.SDL_FRect{
            .x = rect_draw.getX(),
            .y = rect_draw.getY(),
            .w = rect_draw.getWidth(),
            .h = rect_draw.getHeight(),
        };
        if (!sdl.SDL_RenderRect(self.renderer.renderer, &sdlRect)) {
            return error.RenderError;
        }
    }

    pub fn fillRect(self: *RenderEngine, rect_draw: math.rect.Rect2(f32), draw_color: color.Color) !void {
        if (!sdl.SDL_SetRenderDrawColor(
            self.renderer.renderer,
            draw_color.r,
            draw_color.g,
            draw_color.b,
            draw_color.a,
        )) {
            return error.RenderErrorSetColor;
        }
        const sdlRect = sdl.SDL_FRect{
            .x = rect_draw.getX(),
            .y = rect_draw.getY(),
            .w = rect_draw.getWidth(),
            .h = rect_draw.getHeight(),
        };
        if (!sdl.SDL_RenderFillRect(self.renderer.renderer, &sdlRect)) {
            return error.RenderError;
        }
    }

    pub fn drawLine(self: *RenderEngine, start_point: math.vec.Vec2(f32), end_point: math.vec.Vec2(f32), draw_color: color.Color) !void {
        if (!sdl.SDL_SetRenderDrawColor(
            self.renderer.renderer,
            draw_color.r,
            draw_color.g,
            draw_color.b,
            draw_color.a,
        )) {
            return error.RenderErrorSetColor;
        }
        if (!sdl.SDL_RenderLine(self.renderer.renderer, start_point.x, start_point.y, end_point.x, end_point.y)) {
            return error.RenderError;
        }
    }

    pub fn drawTexture(
        self: *RenderEngine,
        texture: *sdl.SDL_Texture,
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
            self.renderer.renderer,
            texture,
            csrc_rect,
            cdst_rect,
        )) {
            return error.RenderError;
        }
    }

    pub fn getTextWidth(self: *RenderEngine, text: [:0]const u8) !i32 {
        var width: i32 = 0;
        for (text) |c| {
            const char_rect = try self.font_atlas.getCharSize(c);
            width += @intFromFloat(char_rect.x);
        }
        return width;
    }

    pub fn drawText(self: *RenderEngine, text: [:0]const u8, location: math.vec.Vec2(f32)) !void {
        var offset = location;
        for (text) |c| {
            try self.font_atlas.renderChar(self.renderer, c, offset);
            const char_rect = try self.font_atlas.getCharSize(c);
            offset.x += char_rect.x;
        }
    }

    pub fn drawChar(self: *RenderEngine, char: u8, location: math.vec.Vec2(f32)) !void {
        const text: [1:0]u8 = .{char};
        var tmp = try self.font_ui.renderTextTexture(&text, self.font_color, self.renderer);
        defer tmp.texture.deinit();
        const text_size = tmp.size;
        try tmp.texture.render(self.renderer, null, math.rect.Rect2(f32).initVec(
            math.vec.Vec2(f32).init(location.x, location.y),
            math.vec.Vec2(f32).init(
                @floatFromInt(text_size.x),
                @floatFromInt(text_size.y),
            ),
        ));
    }

    pub fn drawIcon(self: *RenderEngine, id: usize, dst_rect: math.rect.Rect2(f32)) !void {
        const src_rect = atlas.ATLAS_FONT[id];
        const x = dst_rect.pos.x + (dst_rect.size.x - src_rect.size.x) / 2;
        const y = dst_rect.pos.y + (dst_rect.size.y - src_rect.size.y) / 2;
        return self.texture.render(
            self.renderer,
            src_rect,
            math.rect.Rect2(f32).initVec(math.vec.Vec2(f32).init(x, y), src_rect.size),
        );
    }

    pub fn drawIconTest(self: *RenderEngine) !void {
        const src_rect = atlas.ICON.CLOSE;
        return self.texture.render(self.renderer, src_rect, null);
    }
};
