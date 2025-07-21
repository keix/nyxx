const std = @import("std");
const builtin = @import("builtin");
const devices = @import("../devices.zig");
const FrameBuffer = @import("../ppu.zig").FrameBuffer;
const APU = @import("../apu.zig").APU;

const FRAME_WIDTH = 256;
const FRAME_HEIGHT = 240;
const FRAME_SIZE = FRAME_WIDTH * FRAME_HEIGHT;

// Global buffers for WASM export
var global_frame_buffer: [FRAME_SIZE]u32 = [_]u32{0} ** FRAME_SIZE;
var global_input_state: devices.InputState = .{};

pub const Device = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, args: anytype) !Device {
        _ = args;
        return Device{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Device) void {
        _ = self;
    }

    pub fn renderFrame(self: *Device, frame_buffer: *const FrameBuffer) !void {
        _ = self;
        
        // Copy frame buffer to global buffer with alpha channel
        for (0..FRAME_SIZE) |i| {
            const pixel = frame_buffer.pixels[i];
            global_frame_buffer[i] = 0xFF000000 | pixel;
        }
    }

    pub fn pollInput(self: *Device) devices.InputState {
        _ = self;
        return global_input_state;
    }

    pub fn setAPU(self: *Device, apu: *APU) void {
        _ = self;
        _ = apu;
    }

    pub fn pushAudioSamples(self: *Device, apu: *APU) void {
        _ = self;
        _ = apu;
    }
};

// Export functions for JavaScript interaction
pub fn getFrameBufferPtr() [*]const u32 {
    return &global_frame_buffer;
}

pub fn getFrameWidth() u32 {
    return FRAME_WIDTH;
}

pub fn getFrameHeight() u32 {
    return FRAME_HEIGHT;
}

pub fn setButtonState(controller: u8, button: u8, pressed: bool) void {
    const controller_state = if (controller == 0) &global_input_state.controller1 else &global_input_state.controller2;
    
    switch (button) {
        0 => controller_state.a = pressed,
        1 => controller_state.b = pressed,
        2 => controller_state.select = pressed,
        3 => controller_state.start = pressed,
        4 => controller_state.up = pressed,
        5 => controller_state.down = pressed,
        6 => controller_state.left = pressed,
        7 => controller_state.right = pressed,
        else => {},
    }
}

pub fn setQuit(quit: bool) void {
    global_input_state.quit = quit;
}