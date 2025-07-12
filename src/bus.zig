const std = @import("std");
const APU = @import("apu.zig").APU;
const PPU = @import("ppu.zig").PPU;
const Cartridge = @import("cartridge.zig").Cartridge;
const Controller = @import("controller.zig").Controller;

pub const Bus = struct {
    ram: [2048]u8,
    cartridge: *Cartridge,
    ppu: PPU,
    apu: APU,
    controller1: Controller,
    controller2: Controller,

    pub fn init(cartridge: *Cartridge, allocator: std.mem.Allocator) !Bus {
        const bus = Bus{
            .ram = [_]u8{0} ** 2048,
            .cartridge = cartridge,
            .ppu = PPU.init(cartridge),
            .apu = try APU.init(allocator),
            .controller1 = Controller.init(),
            .controller2 = Controller.init(),
        };
        return bus;
    }

    pub fn deinit(self: *Bus) void {
        self.apu.deinit();
    }

    pub fn loadProgram(self: *Bus, program: []const u8, at: u16) void {
        for (program, 0..) |byte, i| {
            const addr = at + @as(u16, @intCast(i));
            if (addr < 0x2000) {
                self.ram[addr & 0x07FF] = byte;
            }
        }
    }

    pub fn read(self: *Bus, addr: u16) u8 {
        if (self.ppu.dma_active and addr == 0x2007) {
            return self.ppu.open_bus.read();
        }

        return switch (addr) {
            0x0000...0x1FFF => self.ram[addr & 0x07FF],
            0x2000...0x3FFF => self.ppu.readRegister(@intCast(addr & 0x0007)),
            0x4015 => self.apu.read(addr),
            0x4016 => self.controller1.read() | (self.ppu.open_bus.read() & 0xE0),
            0x4017 => self.controller2.read() | (self.ppu.open_bus.read() & 0xE0),
            0x8000...0xFFFF => self.cartridge.read(addr),
            else => 0,
        };
    }

    pub fn write(self: *Bus, addr: u16, value: u8) void {
        switch (addr) {
            0x0000...0x1FFF => self.ram[addr & 0x07FF] = value,
            0x2000...0x3FFF => self.ppu.writeRegister(@intCast(addr & 0x0007), value),
            0x4000...0x4007, 0x4015, 0x4017 => self.apu.write(addr, value),
            0x4014 => self.performOamDma(value),
            0x4016 => self.controllerWrite(value),
            0x8000...0xFFFF => {},
            else => {},
        }
    }

    pub fn readForDMA(self: *Bus, addr: u16) u8 {
        return switch (addr) {
            0x0000...0x1FFF => self.ram[addr & 0x07FF],
            0x8000...0xFFFF => self.cartridge.read(addr),
            else => self.ppu.open_bus.read(),
        };
    }

    fn controllerWrite(self: *Bus, value: u8) void {
        self.controller1.write(value);
        self.controller2.write(value);
        self.ppu.open_bus.write(value);
    }

    fn performOamDma(self: *Bus, page: u8) void {
        self.ppu.dma_active = true;
        const base = @as(u16, page) << 8;
        for (0..256) |i| {
            const data = self.readForDMA(base + @as(u16, @intCast(i)));
            self.ppu.writeOamData(data);
        }
        self.ppu.dma_active = false;
    }
};
