pub const Bus = struct {
    ram: [2048]u8,
    rom: []const u8,
    ppu_mem: [0x4000 - 0x2000]u8 = [_]u8{0} ** (0x4000 - 0x2000),

    pub fn init(rom: []const u8) Bus {
        return Bus{
            .ram = [_]u8{0} ** 2048,
            .rom = rom,
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
            0x2000...0x3FFF => return self.ppu_mem[(addr - 0x2000) % (0x4000 - 0x2000)],
            0x8000...0xFFFF => self.rom[addr],
            else => 0,
        };
    }

    pub fn write(self: *Bus, addr: u16, value: u8) void {
        switch (addr) {
            0x0000...0x1FFF => self.ram[addr & 0x07FF] = value,
            0x2000...0x3FFF => self.ppu_mem[(addr - 0x2000) % (0x4000 - 0x2000)] = value,
            else => {},
        }
    }
};
