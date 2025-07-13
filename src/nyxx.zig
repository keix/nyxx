const std = @import("std");
const Bus = @import("bus.zig").Bus;
const CPU = @import("6502.zig").CPU;
const Cartridge = @import("cartridge.zig").Cartridge;
const FrameBuffer = @import("ppu.zig").FrameBuffer;
const SDLDevice = @import("devices/sdl.zig").Device;

// NES timing constants
const TARGET_CYCLES_PER_FRAME = 29780; // NTSC: ~29780 cycles per frame
const FRAME_TIME_MS: i64 = 16; // ~60 FPS (16.67ms per frame)

pub const Nyxx = struct {
    cartridge: Cartridge,
    bus: Bus,
    cpu: CPU,
    fb: FrameBuffer,
    device: SDLDevice,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, rom_data: []const u8) !*Nyxx {
        var self = try allocator.create(Nyxx);
        errdefer allocator.destroy(self);

        self.allocator = allocator;
        self.cartridge = try Cartridge.loadFromFile(allocator, rom_data);

        self.bus = try Bus.init(&self.cartridge, allocator);
        self.cpu = CPU.init(&self.bus);

        self.fb = FrameBuffer{};
        self.device = try SDLDevice.init(allocator, .{ .title = "Nyxx NES Emulator", .scale = 2 });
        self.device.setAPU(&self.bus.apu);

        std.debug.print("Initial PC: 0x{X:0>4}\n", .{self.cpu.registers.pc});

        return self;
    }

    pub fn deinit(self: *Nyxx) void {
        self.device.deinit();
        self.bus.deinit();
        self.cartridge.deinit(self.allocator);

        const allocator = self.allocator;
        allocator.destroy(self);
    }

    pub fn run(self: *Nyxx) !void {
        std.debug.print("Starting execution...\n", .{});

        var running = true;
        var frame_cycles: u32 = 0;
        var frame_count: u64 = 0;
        var last_frame_time = std.time.milliTimestamp();

        while (running) {
            const cycles = self.cpu.step();
            frame_cycles += cycles;

            for (0..(cycles * 3)) |_| {
                try self.bus.ppu.step(&self.fb);
            }

            self.bus.apu.step(cycles);

            if (frame_cycles >= TARGET_CYCLES_PER_FRAME) {
                frame_cycles -= TARGET_CYCLES_PER_FRAME;
                frame_count += 1;

                self.device.pushAudioSamples(&self.bus.apu);
                try self.device.renderFrame(&self.fb);

                const input = self.device.pollInput();
                if (input.quit) {
                    running = false;
                }
                self.bus.controller1.setFromState(input.controller1);
                self.bus.controller2.setFromState(input.controller2);

                const current_time = std.time.milliTimestamp();
                const frame_duration = current_time - last_frame_time;
                if (frame_duration < FRAME_TIME_MS) {
                    std.time.sleep(@as(u64, @intCast(FRAME_TIME_MS - frame_duration)) * 1_000_000);
                }
                last_frame_time = std.time.milliTimestamp();
            }
        }

        std.debug.print("Emulation stopped.\n", .{});
    }
};
