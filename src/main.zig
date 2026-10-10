const std = @import("std");
const graphic = @import("graphic");
const sdl = graphic.sdl;

const Button = struct {
    rect: sdl.SDL_FRect,
    id: usize,

    pub fn init(rect: sdl.SDL_FRect, id: usize) Button {
        return .{
            .rect = rect,
            .id = id,
        };
    }

    pub fn hover(self: *const Button, x: f32, y: f32) bool {
        return x >= self.rect.x and x <= self.rect.x + self.rect.w and
            y >= self.rect.y and y <= self.rect.y + self.rect.h;
    }

    pub fn drawNormal(self: *const Button, renderer: *sdl.SDL_Renderer) !void {
        if (!sdl.SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255)) {
            return error.RenderErrorSetColor;
        }
        if (!sdl.SDL_RenderFillRect(renderer, &self.rect)) {
            return error.RenderError;
        }
    }

    pub fn drawHover(self: *const Button, renderer: *sdl.SDL_Renderer) !void {
        if (!sdl.SDL_SetRenderDrawColor(renderer, 0, 255, 0, 255)) {
            return error.RenderErrorSetColor;
        }
        if (!sdl.SDL_RenderFillRect(renderer, &self.rect)) {
            return error.RenderError;
        }
    }

    pub fn drawActive(self: *const Button, renderer: *sdl.SDL_Renderer) !void {
        if (!sdl.SDL_SetRenderDrawColor(renderer, 0, 255, 255, 255)) {
            return error.RenderErrorSetColor;
        }
        if (!sdl.SDL_RenderFillRect(renderer, &self.rect)) {
            return error.RenderError;
        }
    }
};

const UI = struct {
    hover_id: usize = 0,
    active_id: usize = 0,
    button_a: Button,
    button_b: Button,

    pub fn init() UI {
        return .{
            .button_a = Button.init(.{ .x = 100, .y = 100, .w = 80, .h = 25 }, 1),
            .button_b = Button.init(.{ .x = 300, .y = 100, .w = 80, .h = 25 }, 2),
        };
    }

    pub fn draw(self: *const UI, renderer: *sdl.SDL_Renderer) !void {
        if (self.active_id != 0) {
            if (self.active_id == self.button_a.id) {
                try self.button_a.drawActive(renderer);
            }
            if (self.active_id == self.button_b.id) {
                try self.button_b.drawActive(renderer);
            }
            return;
        }

        if (self.hover_id == self.button_a.id) {
            try self.button_a.drawHover(renderer);
        } else {
            try self.button_a.drawNormal(renderer);
        }

        if (self.hover_id == self.button_b.id) {
            try self.button_b.drawHover(renderer);
        } else {
            try self.button_b.drawNormal(renderer);
        }
    }

    pub fn mouseMotion(self: *UI, x: f32, y: f32) void {
        self.hover_id = 0;
        if (self.button_a.hover(x, y)) {
            self.hover_id = self.button_a.id;
        }
        if (self.button_b.hover(x, y)) {
            self.hover_id = self.button_b.id;
        }
    }

    pub fn mouseButtonDown(self: *UI, x: f32, y: f32) void {
        self.mouseMotion(x, y);
        if (self.hover_id != 0) {
            self.active_id = self.hover_id;
        }
    }

    pub fn mouseButtonUp(self: *UI, x: f32, y: f32) void {
        self.mouseMotion(x, y);
        if (self.active_id != 0) {
            if (self.hover_id == self.active_id) {
                std.debug.print("click! {}\n", .{self.active_id});
            }
            self.active_id = 0;
        }
    }
};

pub fn main() !void {
    try graphic.initSDL();
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

    var ui = UI.init();

    var is_running = true;
    while (is_running) {
        var event: sdl.SDL_Event = undefined;
        while (sdl.SDL_PollEvent(&event)) {
            switch (event.type) {
                sdl.SDL_EVENT_QUIT => is_running = false,
                sdl.SDL_EVENT_MOUSE_MOTION => ui.mouseMotion(event.motion.x, event.motion.y),
                sdl.SDL_EVENT_MOUSE_BUTTON_DOWN => ui.mouseButtonDown(event.button.x, event.button.y),
                sdl.SDL_EVENT_MOUSE_BUTTON_UP => ui.mouseButtonUp(event.button.x, event.button.y),
                else => {},
            }
        }

        try ui.draw(renderer);

        if (!sdl.SDL_RenderPresent(renderer)) {
            is_running = false;
            continue;
        }
        sdl.SDL_Delay(16);
    }
}
