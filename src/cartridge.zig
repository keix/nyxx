const std = @import("std");

pub const Mirroring = enum { Horizontal, Vertical };

pub const Cartridge = struct {
    prg_rom: []u8,
    chr_rom: []u8,
    chr_ram: [8192]u8 = [_]u8{0} ** 8192,

    mapper: u8,
    reset_vector: u16,
    mirroring: Mirroring,

    pub fn loadFromFile(allocator: std.mem.Allocator, rom_file: []const u8) !Cartridge {
        const header_size = 16;
        const prg_unit = 16 * 1024;
        const chr_unit = 8 * 1024;

        if (rom_file.len < header_size)
            return error.InvalidRomFile;

        const header = rom_file[0..header_size];
        if (!std.mem.eql(u8, header[0..4], "NES\x1A"))
            return error.InvalidRomFile;

        const prg_size = @as(usize, header[4]) * prg_unit;
        const chr_size = @as(usize, header[5]) * chr_unit;
        const has_trainer = (header[6] & 0x04) != 0;

        var trainer_size: usize = 0;
        if (has_trainer) trainer_size = 512;

        const mapper_low = (header[6] >> 4) & 0x0F;
        const mapper_high = header[7] & 0xF0;
        const mapper = mapper_low | mapper_high;

        const prg_start = header_size + trainer_size;
        const chr_start = prg_start + prg_size;

        if (rom_file.len < chr_start + chr_size)
            return error.InvalidRomFile;

        const prg_rom = try allocator.alloc(u8, prg_size);
        const chr_rom = try allocator.alloc(u8, chr_size);

        std.mem.copyForwards(u8, prg_rom, rom_file[prg_start .. prg_start + prg_size]);
        std.mem.copyForwards(u8, chr_rom, rom_file[chr_start .. chr_start + chr_size]);

        const reset_vector = blk: {
            if (prg_size >= 0x8000) {
                // 32KB: $FFFC-$FFFD prg_rom[0x7FFC-0x7FFD]
                const low = prg_rom[0x7FFC];
                const high = prg_rom[0x7FFD];
                break :blk @as(u16, low) | (@as(u16, high) << 8);
            } else {
                // 16KB: $FFFC-$FFFD prg_rom[0x3FFC-0x3FFD]
                const low = prg_rom[0x3FFC];
                const high = prg_rom[0x3FFD];
                break :blk @as(u16, low) | (@as(u16, high) << 8);
            }
        };

        const mirroring = if ((header[6] & 0x01) != 0) Mirroring.Vertical else Mirroring.Horizontal;
        return Cartridge{
            .prg_rom = prg_rom,
            .chr_rom = chr_rom,
            .mapper = mapper,
            .reset_vector = reset_vector,
            .mirroring = mirroring,
        };
    }

    pub fn deinit(self: *const Cartridge, allocator: std.mem.Allocator) void {
        allocator.free(self.prg_rom);
        if (self.chr_rom.len > 0)
            allocator.free(self.chr_rom);
    }

    pub fn read(self: *const Cartridge, addr: u16) u8 {
        if (addr >= 0x8000) {
            const offset = if (self.prg_rom.len == 0x4000)
                (addr - 0x8000) & 0x3FFF // mirror 16KB
            else
                addr - 0x8000;
            return self.prg_rom[offset];
        }
        return 0;
    }

    pub fn getResetVector(self: *const Cartridge) u16 {
        return self.reset_vector;
    }

    pub fn writeCHR(self: *Cartridge, addr: u16, value: u8) void {
        if (self.chr_rom.len > 0) {
            // CHR ROM is read-only, ignore writes
            return;
        }
        if (addr < 0x2000) {
            // CHR RAM
            const offset = addr & 0x1FFF; // 8KB CHR RAM
            if (offset < self.chr_ram.len) {
                self.chr_ram[offset] = value;
            } else {
                // std.debug.print("Attempted to write to CHR RAM out of bounds: 0x{X:04}\n", .{addr});
            }
        }
    }

    pub fn readCHR(self: *const Cartridge, addr: u16) u8 {
        if (addr < 0x2000) {
            // Check if we have CHR ROM first
            if (self.chr_rom.len > 0) {
                // Read from CHR ROM
                const offset = addr & (self.chr_rom.len - 1); // Handle mirroring
                return self.chr_rom[offset];
            } else {
                // No CHR ROM, use CHR RAM
                const offset = addr & 0x1FFF; // 8KB CHR RAM
                if (offset < self.chr_ram.len) {
                    return self.chr_ram[offset];
                } else {
                    // std.debug.print("Attempted to read from CHR RAM out of bounds: 0x{X:04}\n", .{addr});
                }
            }
        }
        return 0;
    }
};
