const std = @import("std");
const FrameBuffer = @import("ppu.zig").FrameBuffer;
const APU = @import("apu.zig").APU;

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

pub const InputState = struct {
    quit: bool = false,
    controller1: ControllerState = .{},
    controller2: ControllerState = .{},
};

pub fn DeviceInterface(comptime DeviceType: type) type {
    return struct {
        device: DeviceType,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, args: anytype) !Self {
            return Self{ .device = try DeviceType.init(allocator, args) };
        }

        pub fn deinit(self: *Self) void {
            self.device.deinit();
        }

        pub fn renderFrame(self: *Self, frame_buffer: *const FrameBuffer) !void {
            return self.device.renderFrame(frame_buffer);
        }

        pub fn pollInput(self: *Self) InputState {
            return self.device.pollInput();
        }

        pub fn setAPU(self: *Self, apu: *APU) void {
            self.device.setAPU(apu);
        }

        pub fn pushAudioSamples(self: *Self, apu: *APU) void {
            self.device.pushAudioSamples(apu);
        }
    };
}
