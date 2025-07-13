const std = @import("std");
const SDL = @import("../sdl.zig").SDL;
const devices = @import("../devices.zig");
const FrameBuffer = @import("../ppu.zig").FrameBuffer;
const APU = @import("../apu.zig").APU;

pub const Device = struct {
    sdl: SDL,

    pub fn init(allocator: std.mem.Allocator, args: anytype) !Device {
        _ = allocator;
        return Device{
            .sdl = try SDL.init(args.title, args.scale),
        };
    }

    pub fn deinit(self: *Device) void {
        self.sdl.deinit();
    }

    pub fn renderFrame(self: *Device, frame_buffer: *const FrameBuffer) !void {
        return self.sdl.renderFrame(frame_buffer);
    }

    pub fn pollInput(self: *Device) devices.InputState {
        if (self.sdl.pollInput()) |sdl_input| {
            return devices.InputState{
                .quit = sdl_input.quit,
                .controller1 = .{
                    .a = sdl_input.controller1.a,
                    .b = sdl_input.controller1.b,
                    .select = sdl_input.controller1.select,
                    .start = sdl_input.controller1.start,
                    .up = sdl_input.controller1.up,
                    .down = sdl_input.controller1.down,
                    .left = sdl_input.controller1.left,
                    .right = sdl_input.controller1.right,
                },
                .controller2 = .{
                    .a = sdl_input.controller2.a,
                    .b = sdl_input.controller2.b,
                    .select = sdl_input.controller2.select,
                    .start = sdl_input.controller2.start,
                    .up = sdl_input.controller2.up,
                    .down = sdl_input.controller2.down,
                    .left = sdl_input.controller2.left,
                    .right = sdl_input.controller2.right,
                },
            };
        }
        return devices.InputState{};
    }

    pub fn setAPU(self: *Device, apu: *APU) void {
        self.sdl.setAPU(apu);
    }

    pub fn pushAudioSamples(self: *Device, apu: *APU) void {
        _ = self;
        SDL.pushAudioSamples(apu);
    }
};