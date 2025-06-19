const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

// Check if we're in a headless environment
fn isHeadless() bool {
    const display = std.process.getEnvVarOwned(std.heap.page_allocator, "DISPLAY") catch return true;
    defer std.heap.page_allocator.free(display);
    return display.len == 0;
}

const FrameBuffer = @import("ppu.zig").FrameBuffer;

// NES resolution
const NES_WIDTH = 256;
const NES_HEIGHT = 240;

// NES color palette (NTSC)
const NES_PALETTE = [_]u32{
    0x7C7C7C, 0x0000FC, 0x0000BC, 0x4428BC, 0x940084, 0xA80020, 0xA81000, 0x881400,
    0x503000, 0x007800, 0x006800, 0x005800, 0x004058, 0x000000, 0x000000, 0x000000,
    0xBCBCBC, 0x0078F8, 0x0058F8, 0x6844FC, 0xD800CC, 0xE40058, 0xF83800, 0xE45C10,
    0xAC7C00, 0x00B800, 0x00A800, 0x00A844, 0x008888, 0x000000, 0x000000, 0x000000,
    0xF8F8F8, 0x3CBCFC, 0x6888FC, 0x9878F8, 0xF878F8, 0xF85898, 0xF87858, 0xFCA044,
    0xF8B800, 0xB8F818, 0x58D854, 0x58F898, 0x00E8D8, 0x787878, 0x000000, 0x000000,
    0xFCFCFC, 0xA4E4FC, 0xB8B8F8, 0xD8B8F8, 0xF8B8F8, 0xF8A4C0, 0xF0D0B0, 0xFCE0A8,
    0xF8D878, 0xD8F878, 0xB8F8B8, 0xB8F8D8, 0x00FCFC, 0xF8D8F8, 0x000000, 0x000000,
};

pub const InputState = struct {
    quit: bool = false,
    controller1: ControllerState = .{},
    controller2: ControllerState = .{},
};

pub const ControllerState = packed struct {
    a: bool = false,
    b: bool = false,
    select: bool = false,
    start: bool = false,
    up: bool = false,
    down: bool = false,
    left: bool = false,
    right: bool = false,
};

pub const SDL = struct {
    window: ?*c.SDL_Window,
    renderer: ?*c.SDL_Renderer,
    texture: ?*c.SDL_Texture,
    scale: u8,

    pub fn init(title: []const u8, scale: u8) !SDL {
        // Use dummy driver if headless
        if (isHeadless()) {
            std.log.info("Headless environment detected, using SDL dummy driver", .{});
            _ = c.SDL_SetHint(c.SDL_HINT_VIDEODRIVER, "dummy");
        }

        if (c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_AUDIO) != 0) {
            std.log.err("SDL_Init failed: {s}", .{c.SDL_GetError()});
            return error.SDLInitFailed;
        }

        const window = c.SDL_CreateWindow(
            title.ptr,
            c.SDL_WINDOWPOS_CENTERED,
            c.SDL_WINDOWPOS_CENTERED,
            @as(c_int, NES_WIDTH) * @as(c_int, scale),
            @as(c_int, NES_HEIGHT) * @as(c_int, scale),
            c.SDL_WINDOW_SHOWN,
        );

        if (window == null) {
            std.log.err("SDL_CreateWindow failed: {s}", .{c.SDL_GetError()});
            c.SDL_Quit();
            return error.SDLWindowFailed;
        }

        const renderer = c.SDL_CreateRenderer(
            window,
            -1,
            c.SDL_RENDERER_SOFTWARE, // Use software renderer for compatibility
        );

        if (renderer == null) {
            std.log.err("SDL_CreateRenderer failed: {s}", .{c.SDL_GetError()});
            c.SDL_DestroyWindow(window);
            c.SDL_Quit();
            return error.SDLRendererFailed;
        }

        const texture = c.SDL_CreateTexture(
            renderer,
            c.SDL_PIXELFORMAT_ARGB8888,
            c.SDL_TEXTUREACCESS_STREAMING,
            NES_WIDTH,
            NES_HEIGHT,
        );

        if (texture == null) {
            std.log.err("SDL_CreateTexture failed: {s}", .{c.SDL_GetError()});
            c.SDL_DestroyRenderer(renderer);
            c.SDL_DestroyWindow(window);
            c.SDL_Quit();
            return error.SDLTextureFailed;
        }

        return SDL{
            .window = window,
            .renderer = renderer,
            .texture = texture,
            .scale = scale,
        };
    }

    pub fn deinit(self: *SDL) void {
        if (self.texture) |texture| c.SDL_DestroyTexture(texture);
        if (self.renderer) |renderer| c.SDL_DestroyRenderer(renderer);
        if (self.window) |window| c.SDL_DestroyWindow(window);
        c.SDL_Quit();
    }

    pub fn renderFrame(self: *SDL, frame_buffer: *const FrameBuffer) !void {
        var pixels: ?*anyopaque = undefined;
        var pitch: c_int = undefined;

        if (c.SDL_LockTexture(self.texture, null, &pixels, &pitch) != 0) {
            std.log.err("SDL_LockTexture failed: {s}", .{c.SDL_GetError()});
            return error.SDLLockTextureFailed;
        }
        defer c.SDL_UnlockTexture(self.texture);

        // Copy frame buffer directly (already contains RGB values)
        const pixel_data = @as([*]u32, @ptrCast(@alignCast(pixels)));
        for (frame_buffer.pixels, 0..) |pixel, i| {
            // Frame buffer already contains RGB color values (0xRRGGBB format)
            // Convert to ARGB format for SDL
            pixel_data[i] = 0xFF000000 | pixel;
        }

        // Render to screen
        _ = c.SDL_RenderClear(self.renderer);
        _ = c.SDL_RenderCopy(self.renderer, self.texture, null, null);
        c.SDL_RenderPresent(self.renderer);
    }

    pub fn pollInput(self: *SDL) ?InputState {
        _ = self;
        var state = InputState{};
        var event: c.SDL_Event = undefined;

        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_QUIT => state.quit = true,
                c.SDL_KEYDOWN => {
                    switch (event.key.keysym.sym) {
                        // Controller 1 mapping
                        c.SDLK_z => state.controller1.a = true,
                        c.SDLK_x => state.controller1.b = true,
                        c.SDLK_SPACE => state.controller1.select = true,
                        c.SDLK_RETURN => state.controller1.start = true,
                        c.SDLK_UP => state.controller1.up = true,
                        c.SDLK_DOWN => state.controller1.down = true,
                        c.SDLK_LEFT => state.controller1.left = true,
                        c.SDLK_RIGHT => state.controller1.right = true,
                        // ESC to quit
                        c.SDLK_ESCAPE => state.quit = true,
                        else => {},
                    }
                },
                c.SDL_KEYUP => {
                    switch (event.key.keysym.sym) {
                        // Controller 1 mapping
                        c.SDLK_z => state.controller1.a = false,
                        c.SDLK_x => state.controller1.b = false,
                        c.SDLK_SPACE => state.controller1.select = false,
                        c.SDLK_RETURN => state.controller1.start = false,
                        c.SDLK_UP => state.controller1.up = false,
                        c.SDLK_DOWN => state.controller1.down = false,
                        c.SDLK_LEFT => state.controller1.left = false,
                        c.SDLK_RIGHT => state.controller1.right = false,
                        else => {},
                    }
                },
                else => {},
            }
        }

        return state;
    }
};
