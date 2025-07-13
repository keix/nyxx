const std = @import("std");
const Bus = @import("bus.zig").Bus;
const CPU = @import("6502.zig").CPU;
const Cartridge = @import("cartridge.zig").Cartridge;
const FrameBuffer = @import("ppu.zig").FrameBuffer;
const SDL = @import("sdl.zig").SDL;

pub const Nyxx = struct {
    pub fn initAndRun(allocator: std.mem.Allocator, rom_data: []const u8) !void {
        var cartridge = try Cartridge.loadFromFile(allocator, rom_data);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();

        var cpu = CPU.init(&bus);

        std.debug.print("Initial PC: 0x{X:0>4}\n", .{cpu.registers.pc});
        std.debug.print("Starting execution...\n", .{});

        var sdl = try SDL.init("Nyxx NES Emulator", 2);
        defer sdl.deinit();

        sdl.setAPU(&bus.apu);

        var fb = FrameBuffer{};
        var running = true;
        var frame_cycles: u32 = 0;
        const target_cycles = 29780;
        var frame_count: u64 = 0;
        var last_frame_time = std.time.milliTimestamp();
        const frame_time_ms: i64 = 16;

        while (running) {
            const cycles = cpu.step();
            frame_cycles += cycles;

            for (0..(cycles * 3)) |_| {
                try bus.ppu.step(&fb);
            }

            bus.apu.step(cycles);

            if (frame_cycles >= target_cycles) {
                frame_cycles -= target_cycles;
                frame_count += 1;

                SDL.pushAudioSamples(&bus.apu);
                try sdl.renderFrame(&fb);

                if (sdl.pollInput()) |input| {
                    if (input.quit) {
                        running = false;
                    }
                    bus.controller1.setFromState(input.controller1);
                    bus.controller2.setFromState(input.controller2);
                }

                const current_time = std.time.milliTimestamp();
                const frame_duration = current_time - last_frame_time;
                if (frame_duration < frame_time_ms) {
                    std.time.sleep(@as(u64, @intCast(frame_time_ms - frame_duration)) * 1_000_000);
                }
                last_frame_time = std.time.milliTimestamp();
            }
        }

        std.debug.print("Emulation stopped.\n", .{});
    }
};
