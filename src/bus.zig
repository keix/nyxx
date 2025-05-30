const PPU = @import("ppu.zig").PPU;
const Cartridge = @import("cartridge.zig").Cartridge;
const std = @import("std");

pub const Bus = struct {
    ram: [2048]u8,
    cartridge: *Cartridge,
    ppu: PPU,

    pub fn init(cartridge: *Cartridge) Bus {
        const bus = Bus{
            .ram = [_]u8{0} ** 2048,
            .cartridge = cartridge,
            .ppu = PPU.init(cartridge),
        };
        return bus;
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
        return switch (addr) {
            0x0000...0x1FFF => self.ram[addr & 0x07FF],
            0x2000...0x3FFF => {
                const reg: u3 = @intCast(addr & 0x0007);
                return self.ppu.readRegister(reg);
            },
            0x8000...0xFFFF => self.cartridge.read(addr),
            else => 0,
        };
    }

    pub fn write(self: *Bus, addr: u16, value: u8) void {
        switch (addr) {
            0x0000...0x1FFF => self.ram[addr & 0x07FF] = value,
            0x2000...0x3FFF => {
                const reg: u3 = @intCast(addr & 0x0007);
                self.ppu.writeRegister(reg, value);
            },
            0x8000...0xFFFF => {},
            else => {},
        }
    }
};
