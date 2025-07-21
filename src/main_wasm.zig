const std = @import("std");
const Nyxx = @import("nyxx.zig").Nyxx;

var nyxx_instance: ?*Nyxx = null;
var rom_buffer: []u8 = undefined;
var allocator_buffer: [1024 * 1024 * 16]u8 = undefined; // 16MB heap
var fba = std.heap.FixedBufferAllocator.init(&allocator_buffer);

export fn init(rom_size: usize) ?[*]u8 {
    const allocator = fba.allocator();
    rom_buffer = allocator.alloc(u8, rom_size) catch return null;
    return rom_buffer.ptr;
}

export fn start() bool {
    const allocator = fba.allocator();
    nyxx_instance = Nyxx.init(allocator, rom_buffer) catch return false;
    return true;
}

export fn step() void {
    if (nyxx_instance) |nyxx| {
        // Run one frame worth of cycles
        var frame_cycles: u32 = 0;
        const TARGET_CYCLES_PER_FRAME = 29780;

        while (frame_cycles < TARGET_CYCLES_PER_FRAME) {
            const cycles = nyxx.cpu.step();
            frame_cycles += cycles;

            for (0..(cycles * 3)) |_| {
                nyxx.bus.ppu.step(&nyxx.fb) catch {};
            }

            nyxx.bus.apu.step(cycles);
        }

        nyxx.device.pushAudioSamples(&nyxx.bus.apu);
        nyxx.device.renderFrame(&nyxx.fb) catch {};

        const input = nyxx.device.pollInput();
        nyxx.bus.controller1.setFromState(input.controller1);
        nyxx.bus.controller2.setFromState(input.controller2);
    }
}

export fn deinit() void {
    if (nyxx_instance) |nyxx| {
        nyxx.deinit();
        nyxx_instance = null;
    }
    fba.reset();
}

// Re-export WebGL device functions
const webgl = @import("devices/webgl.zig");

export fn getFrameBufferPtr() [*]const u32 {
    return webgl.getFrameBufferPtr();
}

export fn getFrameWidth() u32 {
    return webgl.getFrameWidth();
}

export fn getFrameHeight() u32 {
    return webgl.getFrameHeight();
}

export fn setButtonState(controller: u8, button: u8, pressed: bool) void {
    webgl.setButtonState(controller, button, pressed);
}

export fn setQuit(quit: bool) void {
    webgl.setQuit(quit);
}
