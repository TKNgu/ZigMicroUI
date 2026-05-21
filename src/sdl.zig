pub const csdl = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3_image/SDL_image.h");
    @cInclude("SDL3_ttf/SDL_ttf.h");
});

pub const Window = struct {
    window: *csdl.SDL_Window,

    pub fn init(title: [:0]const u8, width: i32, height: i32) !Window {
        const window = csdl.SDL_CreateWindow(title, width, height, csdl.SDL_WINDOW_VULKAN);
        if (window == null) {
            return error.SDLCreateWindowFailed;
        }
        return Window{
            .window = window.?,
        };
    }

    pub fn deinit(self: *Window) void {
        csdl.SDL_DestroyWindow(self.window);
    }
};

pub const Renderer = struct {
    renderer: *csdl.SDL_Renderer,

    pub fn init(window: *Window) !Renderer {
        const renderer = csdl.SDL_CreateRenderer(window.window, null);
        if (renderer == null) {
            return error.SDLCreateRendererFailed;
        }
        return Renderer{
            .renderer = renderer.?,
        };
    }

    pub fn deinit(self: *Renderer) void {
        csdl.SDL_DestroyRenderer(self.renderer);
    }

    pub fn clear(self: *Renderer, r: u8, g: u8, b: u8, a: u8) bool {
        return csdl.SDL_SetRenderDrawColor(self.renderer, r, g, b, a) and
            csdl.SDL_RenderClear(self.renderer);
    }

    pub fn present(self: *Renderer) bool {
        return csdl.SDL_RenderPresent(self.renderer);
    }
};
