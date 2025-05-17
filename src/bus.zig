pub const Bus = struct {
    ram: [2048]u8,
    rom: [65536]u8 = [_]u8{0} ** 65536,

    pub fn init() Bus {
        return Bus{
            .ram = [_]u8{0} ** 2048,
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

    pub fn loadTestRom(self: *Bus, rom_data: []const u8) void {
        const base: u16 = 0x8000;

        for (rom_data, 0..) |byte, i| {
            self.rom[base + @as(u16, @intCast(i))] = byte;
        }

        // Set reset vector to 0x8000
        self.rom[0xFFFC] = 0x00;
        self.rom[0xFFFD] = 0x80;
    }

    pub fn read(self: *Bus, addr: u16) u8 {
        return switch (addr) {
            0x0000...0x1FFF => self.ram[addr & 0x07FF],
            0x8000...0xFFFF => self.rom[addr], // Assuming ROM is loaded here
            else => 0,
        };
    }

    pub fn write(self: *Bus, addr: u16, value: u8) void {
        switch (addr) {
            0x0000...0x1FFF => self.ram[addr & 0x07FF] = value,
            0x8000...0xFFFF => self.rom[addr] = value, // Assuming ROM is not writable
            else => {},
        }
    }
};
