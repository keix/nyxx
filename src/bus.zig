const PPU = @import("ppu.zig").PPU;
const Cartridge = @import("cartridge.zig").Cartridge;

pub const Bus = struct {
    ram: [2048]u8,
    cartridge: *const Cartridge,
    ppu: PPU,

    pub fn init(cartridge: *const Cartridge) Bus {
        return Bus{
            .ram = [_]u8{0} ** 2048,
            .ppu = PPU{},
            .cartridge = cartridge,
        };
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
            0x2000...0x3FFF => self.ppu.readRegister(@as(u3, @intCast((addr & 0x07)))),
            0x8000...0xFFFF => self.cartridge.read(addr),
            else => 0,
        };
    }

    pub fn write(self: *Bus, addr: u16, value: u8) void {
        switch (addr) {
            0x0000...0x1FFF => self.ram[addr & 0x07FF] = value,
            0x2000...0x3FFF => self.ppu.writeRegister(@as(u3, @intCast(addr & 0x07)), value),
            0x8000...0xFFFF => @panic("Attempted to write to ROM address"),
            else => {},
        }
    }
};
