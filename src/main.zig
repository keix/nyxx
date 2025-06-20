const std = @import("std");
const Bus = @import("bus.zig").Bus;
const CPU = @import("6502.zig").CPU;
const Cart = @import("cartridge.zig").Cartridge;
const FrameBuffer = @import("ppu.zig").FrameBuffer;
const SDL = @import("sdl.zig").SDL;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const allocator = std.heap.page_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try stdout.print("Usage: {s} $ROM_FILE_PATH\n", .{args[0]});
        return error.InvalidArgument;
    }

    const path = args[1];
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try allocator.alloc(u8, file_size);
    defer allocator.free(buffer);

    _ = try file.readAll(buffer);

    var cartridge = try Cart.loadFromFile(allocator, buffer);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    try stdout.print("Initial PC: 0x{X:0>4}\n", .{cpu.registers.pc});

    // Initialize SDL
    var sdl = try SDL.init("Nyxx NES Emulator", 2);
    defer sdl.deinit();
    
    // Connect APU to SDL for audio output
    sdl.setAPU(&bus.apu);

    var fb = FrameBuffer{};

    try stdout.print("Starting execution...\n", .{});

    // Main emulation loop
    var running = true;
    var frame_cycles: u32 = 0;
    const target_cycles = 29780;
    var frame_count: u64 = 0;
    var last_frame_time = std.time.milliTimestamp();
    const frame_time_ms: i64 = 16; // ~60 FPS (16.67ms per frame)

    while (running) {
        // Execute CPU instruction
        const cycles = cpu.step();
        frame_cycles += cycles;

        // Execute PPU cycles (3 PPU cycles per CPU cycle)
        for (0..(cycles * 3)) |_| {
            try bus.ppu.step(&fb);
        }

        // Execute APU cycles (APU runs at half CPU speed)
        bus.apu.step(cycles);

        // Check if frame is complete
        if (frame_cycles >= target_cycles) {
            frame_cycles -= target_cycles;
            frame_count += 1;
            
            // Push audio samples to SDL once per frame
            SDL.pushAudioSamples(&bus.apu);

            // Render frame to SDL
            try sdl.renderFrame(&fb);

            // Poll for input
            if (sdl.pollInput()) |input| {
                if (input.quit) {
                    running = false;
                }

                // Update controller states
                bus.controller1.setFromState(input.controller1);
                bus.controller2.setFromState(input.controller2);
            }
            
            // Frame rate limiting
            const current_time = std.time.milliTimestamp();
            const frame_duration = current_time - last_frame_time;
            if (frame_duration < frame_time_ms) {
                std.time.sleep(@as(u64, @intCast(frame_time_ms - frame_duration)) * 1_000_000);
            }
            last_frame_time = std.time.milliTimestamp();
        }
    }

    try stdout.print("Emulation stopped.\n", .{});
}
