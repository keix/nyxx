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

    pub fn readForDMA(self: *Bus, addr: u16) u8 {
        return switch (addr) {
            0x0000...0x1FFF => self.ram[addr & 0x07FF],
            0x8000...0xFFFF => self.cartridge.read(addr),
            else => self.ppu.open_bus,
        };
    }

    pub fn read(self: *Bus, addr: u16) u8 {
        if (self.ppu.dma_active and addr == 0x2007) {
            return self.ppu.open_bus;
        }

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
        if (addr == 0x4014) {
            self.ppu.dma_active = true;
            const base = @as(u16, value) << 8;
            var i: u16 = 0;
            while (i < 256) : (i += 1) {
                const data = self.readForDMA(base + i);
                self.ppu.writeOamData(data);
            }
            self.ppu.dma_active = false;
            return;
        }
        switch (addr) {
            0x0000...0x1FFF => self.ram[addr & 0x07FF] = value,
            0x2000...0x3FFF => {
                const reg: u3 = @intCast(addr & 0x0007);
                self.ppu.writeRegister(reg, value);
            },
            //           0x6000...0x7FFF => {
            //               std.debug.print("Ignoring write to mapper RAM at {x}\n", .{addr});
            //           },
            0x8000...0xFFFF => {},
            else => {},
        }
    }
};
