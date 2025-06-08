const std = @import("std");
const Bus = @import("bus.zig").Bus;
const Cartridge = @import("cartridge.zig").Cartridge;
const Mirroring = @import("cartridge.zig").Mirroring;

const ONE_SECOND = 60;

const VISIBLE_SCANLINES = 240;
const CYCLES_PER_SCANLINE = 341;
const SCANLINES_PER_FRAME = 262;

pub const FrameBuffer = struct {
    pixels: [VISIBLE_SCANLINES * 256]u32 = [_]u32{0} ** (VISIBLE_SCANLINES * 256),

    pub fn setPixel(self: *FrameBuffer, x: u8, y: u8, color: u32) void {
        if (y < VISIBLE_SCANLINES and x < 256) {
            self.pixels[@as(usize, y) * 256 + x] = color;
        }
    }

    pub fn getPixel(self: *FrameBuffer, x: u8, y: u8) u32 {
        if (y < VISIBLE_SCANLINES and x < 256) {
            return self.pixels[@as(usize, y) * 256 + x];
        }
        return 0;
    }

    pub fn writePPM(self: *const FrameBuffer, filename: []const u8) !void {
        var file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();

        try file.writer().print("P3\n256 {d}\n255\n", .{VISIBLE_SCANLINES});
        for (self.pixels) |pixel| {
            const r: u8 = @intCast((pixel >> 16) & 0xFF);
            const g: u8 = @intCast((pixel >> 8) & 0xFF);
            const b: u8 = @intCast(pixel & 0xFF);
            try file.writer().print("{} {} {}\n", .{ r, g, b });
        }
    }
};

pub const VRAM = struct {
    memory: [0x4000]u8 = [_]u8{0} ** 0x4000,
    palette: [32]u8 = [_]u8{0} ** 32,
    buffer: u8 = 0, // Buffer for PPU data reads
    mirroring: Mirroring,

    pub fn init(mirroring: Mirroring) VRAM {
        var vram = VRAM{
            .memory = [_]u8{0} ** 0x4000,
            .palette = [_]u8{0} ** 32,
            .mirroring = mirroring,
        };

        vram.palette = [_]u8{
            0x01, 0x23, 0x27, 0x30, // BG Palette 0
            0x0F, 0x2D, 0x3A, 0x12, // BG Palette 1
            0x1C, 0x2B, 0x3C, 0x0A, // BG Palette 2
            0x1E, 0x2E, 0x3E, 0x0C, // BG Palette 3
            0x0F, 0x3D, 0x2C, 0x1A, // Sprite Palette 0
            0x1D, 0x2F, 0x3F, 0x0B, // Sprite Palette 1
            0x0E, 0x3E, 0x2A, 0x09, // Sprite Palette 2
            0x1F, 0x2D, 0x3B, 0x0D, // Sprite Palette 3
        };

        return vram;
    }

    pub fn read(self: *VRAM, addr: u16) u8 {
        const resolved_addr = switch (addr) {
            0x3000...0x3EFF => addr - 0x1000,
            else => addr,
        };

        if (resolved_addr >= 0x2000 and resolved_addr < 0x3000) {
            const mirrored = self.resolveMirroredAddr(resolved_addr);
            return self.memory[mirrored];
        }

        // return self.memory[resolved_addr];
        std.debug.panic("VRAM read invalid address: 0x{X}", .{addr});
    }

    pub fn write(self: *VRAM, addr: u16, value: u8) void {
        const resolved_addr = switch (addr) {
            0x3000...0x3EFF => addr - 0x1000,
            else => addr,
        };

        if (resolved_addr >= 0x2000 and resolved_addr < 0x3000) {
            const mirrored = self.resolveMirroredAddr(resolved_addr);
            self.memory[0x2000 + mirrored] = value;
            return;
        }

        std.debug.panic("VRAM write invalid address: 0x{X}", .{addr});
    }

    pub fn readPalette(self: *VRAM, addr: u16) u8 {
        const palette_addr = self.resolvePaletteAddr(addr);
        return self.palette[palette_addr];
    }

    pub fn writePalette(self: *VRAM, addr: u16, value: u8) void {
        const palette_addr = self.resolvePaletteAddr(addr);
        self.palette[palette_addr] = value;
    }

    fn resolvePaletteAddr(_: *VRAM, addr: u16) u16 {
        var palette_addr = addr & 0x1F;
        if (palette_addr == 0x10) palette_addr = 0x00;
        if (palette_addr == 0x14) palette_addr = 0x04;
        if (palette_addr == 0x18) palette_addr = 0x08;
        if (palette_addr == 0x1C) palette_addr = 0x0C;
        return palette_addr;
    }

    fn resolveMirroredAddr(self: *VRAM, addr: u16) u16 {
        const offset = addr - 0x2000;
        const name_table_index = offset / 0x400;
        const local_offset = offset % 0x400;

        return switch (self.mirroring) {
            .Vertical => switch (name_table_index) {
                0, 2 => local_offset,
                1, 3 => 0x400 + local_offset,
                else => std.debug.panic("Invalid name table index: {d}", .{name_table_index}),
            },
            .Horizontal => switch (name_table_index) {
                0, 1 => local_offset,
                2, 3 => 0x400 + local_offset,
                else => std.debug.panic("Invalid name table index: {d}", .{name_table_index}),
            },
        };
    }
};

const NES_PALETTE = [_]u32{
    0x666666, 0x002A88, 0x1412A7, 0x3B00A4, 0x5C007E, 0x6E0040, 0x6C0600, 0x561D00,
    0x333500, 0x0B4800, 0x005200, 0x004F08, 0x00404D, 0x000000, 0x000000, 0x000000,
    0xADADAD, 0x155FD9, 0x4240FF, 0x7527FE, 0xA01ACC, 0xB71E7B, 0xB53120, 0x994E00,
    0x6B6D00, 0x388700, 0x0C9300, 0x008F32, 0x007C8D, 0x000000, 0x000000, 0x000000,
    0xFFFEFF, 0x64B0FF, 0x9290FF, 0xC676FF, 0xF36AFF, 0xFE6ECC, 0xFE8170, 0xEA9E22,
    0xBCBE00, 0x88D800, 0x5CE430, 0x45E082, 0x48CDDE, 0x4F4F4F, 0x000000, 0x000000,
    0xFFFEFF, 0xC0DFFF, 0xD3D2FF, 0xE8C8FF, 0xFBC2FF, 0xFEC4EA, 0xFECCC5, 0xF7D8A5,
    0xE4E594, 0xCFEF96, 0xBDF4AB, 0xB3F3CC, 0xB5EBF2, 0xB8B8B8, 0x000000, 0x000000,
};

const Mask = packed struct {
    grayscale: bool,
    show_bg_left: bool,
    show_sprites_left: bool,
    show_bg: bool,
    show_sprites: bool,
    emphasize_red: bool,
    emphasize_green: bool,
    emphasize_blue: bool,

    pub fn write(self: *Mask, value: u8) void {
        self.* = @bitCast(value);
    }

    pub fn read(self: Mask) u8 {
        return @bitCast(self);
    }
};

const Status = packed struct {
    unused: u5 = 0,
    sprite_overflow: bool,
    sprite0_hit: bool,
    vblank: bool,

    pub fn read(self: *Status) u8 {
        const result: u8 = @bitCast(self.*);
        self.vblank = false;
        return result;
    }
};

const LoopyRegister = packed struct {
    coarse_x: u5 = 0,
    coarse_y: u5 = 0,
    nametable: u2 = 0,
    fine_y: u3 = 0,
    unused: u1 = 0,

    pub fn read(self: LoopyRegister) u16 {
        return @bitCast(self);
    }

    pub fn write(self: *LoopyRegister, value: u16) void {
        self.* = @bitCast(value & 0x7FFF);
    }
};

const ScrollUnit = struct {
    v: LoopyRegister = .{}, // current VRAM address
    t: LoopyRegister = .{}, // temporary VRAM address
    x: u3 = 0, // fine X scroll (0-7)
    w: bool = false, // write toggle

    pub fn writeScroll(self: *ScrollUnit, value: u8) void {
        if (!self.w) {
            self.t.coarse_x = @truncate(value >> 3);
            self.x = @truncate(value & 0b0000_0111);
        } else {
            self.t.coarse_y = @truncate(value >> 3);
            self.t.fine_y = @truncate(value & 0b0000_0111);
        }
        self.w = !self.w;
    }

    pub fn writeAddr(self: *ScrollUnit, value: u8) void {
        if (!self.w) {
            const current = self.t.read() & 0x00FF;
            self.t.write((@as(u16, value & 0x3F) << 8) | current);
        } else {
            const current = self.t.read() & 0x7F00;
            self.t.write(current | value);
            self.v = self.t;
        }
        self.w = !self.w;
    }

    pub fn resetLatch(self: *ScrollUnit) void {
        self.w = false;
    }

    pub fn incrementHorizontal(self: *ScrollUnit) void {
        if (self.v.coarse_x == 31) {
            self.v.coarse_x = 0;
            self.v.nametable ^= 0b01;
        } else {
            self.v.coarse_x += 1;
        }
    }

    pub fn incrementVertical(self: *ScrollUnit) void {
        if (self.v.fine_y < 7) {
            self.v.fine_y += 1;
        } else {
            self.v.fine_y = 0;
            if (self.v.coarse_y == 29) {
                self.v.coarse_y = 0;
                self.v.nametable ^= 0b10;
            } else if (self.v.coarse_y == 31) {
                self.v.coarse_y = 0;
            } else {
                self.v.coarse_y += 1;
            }
        }
    }
};

const Registers = struct {
    ctrl: u8 = 0, // $2000
    mask: Mask = @bitCast(@as(u8, 0)), // $2001
    status: Status = @bitCast(@as(u8, 0)), // $2002
    oam_addr: u8 = 0, // $2003
    oam_data: [256]u8 = [_]u8{0} ** 256, // $2004
    scroll_unit: ScrollUnit = .{}, // $2005 + $2006 + fine X scroll
};

pub const PPU = struct {
    registers: Registers,
    vram: VRAM,
    _vblank_injected: bool = false,

    cycle: u16 = 0,
    scanline: i16 = 0, // -1 (pre-render) 〜 260 (post-render)
    frame: usize = 0,
    cartridge: *Cartridge,
    open_bus: u8 = 0, // Open bus for PPU read operations
    dma_active: bool = false,
    oam_accessing: bool = false,
    open_bus_decay_counter: u8 = 0, // Decay counter for open bus

    pub fn dumpNameTable(self: *PPU) void {
        const start = 0x2000;
        const end = 0x23C0;
        for (start..end) |addr| {
            if ((addr - start) % 32 == 0) {
                std.debug.print("\n0x{X:04}: ", .{addr});
            }
            std.debug.print("{X:02} ", .{self.vram.memory[addr]});
        }
        std.debug.print("\n", .{});
    }

    fn debugV(v: u16) void {
        std.debug.print("PPU V register: 0x{X:04} (coarse_x={d}, coarse_y={d}, fine_y={d}, nametable={d})\n", .{
            v,
            v & 0x1F, // coarse_x
            (v >> 5) & 0x1F, // coarse_y
            (v >> 12) & 0x07, // fine_y
            (v >> 10) & 0x03, // nametable
        });
    }

    pub fn init(cartridge: *Cartridge) PPU {
        return PPU{
            .registers = .{},
            .vram = VRAM.init(cartridge.mirroring),
            ._vblank_injected = false,
            .cycle = 0,
            .scanline = -1, // pre-render line
            .frame = 0,
            .cartridge = cartridge,
        };
    }

    pub fn step(self: *PPU, fb: *FrameBuffer) !void {
        if (self.scanline >= 0 and self.scanline < 240 and self.cycle >= 1 and self.cycle <= 256) {
            try self.renderPixel(fb);
        }

        if (self.scanline == 241 and self.cycle == 1) {
            self.registers.status.vblank = true;
        }

        if (self.scanline == 261 and self.cycle == 1) {
            self.registers.status.vblank = false;
            self._vblank_injected = false;
            self.registers.status.sprite0_hit = false; // Reset sprite 0 hit flag
        }

        self.cycle += 1;
        if (self.cycle > 340) {
            self.cycle = 0;
            self.scanline += 1;
            if (self.scanline > 261) {
                self.scanline = 0;
                self.frame += 1;
            }
        }

        if (self.scanline == 261 and self.cycle == 0) {
            if (self.open_bus_decay_counter < ONE_SECOND) {
                self.open_bus_decay_counter += 1;
            }
            if (self.open_bus_decay_counter >= ONE_SECOND) {
                self.open_bus = 0;
            }
        }
    }

    pub fn isFrameComplete(self: *PPU) bool {
        return self.scanline == 0 and self.cycle == 0;
    }

    fn renderPixel(self: *PPU, fb: *FrameBuffer) !void {
        if (self.cartridge.chr_rom.len == 0) return;

        const x: u16 = @intCast(self.cycle - 1);
        const y: u16 = @intCast(self.scanline);

        const tile_x = x / 8;
        const tile_y = y / 8;
        const name_table_index = tile_y * 32 + tile_x;
        const tile_id = self.vram.memory[0x2000 + @as(u16, name_table_index)];

        const pixel_x: u3 = @intCast(x % 8);
        const pixel_y: u3 = @intCast(y % 8);

        const chr_index = @as(usize, tile_id) * 16;
        const plane0 = self.cartridge.chr_rom[chr_index + pixel_y];
        const plane1 = self.cartridge.chr_rom[chr_index + 8 + pixel_y];

        const bit_index: u3 = 7 - pixel_x;
        const bit0 = (plane0 >> bit_index) & 1;
        const bit1 = (plane1 >> bit_index) & 1;
        const color_index = (bit1 << 1) | bit0;

        if (!self.registers.status.sprite0_hit and
            y < 240 and x < 256 and color_index != 0)
        {
            const sprite_y = self.registers.oam_data[0];
            const sprite_tile = self.registers.oam_data[1];
            const sprite_x = self.registers.oam_data[3];

            if (y >= sprite_y and y < sprite_y + 8 and x >= sprite_x and x < sprite_x + 8) {
                const sprite_pixel_y: u3 = @intCast(y - sprite_y);
                const sprite_chr_index: usize = @as(usize, sprite_tile) * 16;
                const sprite_plane0 = self.cartridge.chr_rom[sprite_chr_index + sprite_pixel_y];
                const sprite_plane1 = self.cartridge.chr_rom[sprite_chr_index + 8 + sprite_pixel_y];
                const sprite_bit_x: u3 = @intCast(x - sprite_x);
                const sprite_bit_index: u3 = 7 - sprite_bit_x;

                const sbit0 = (sprite_plane0 >> sprite_bit_index) & 1;
                const sbit1 = (sprite_plane1 >> sprite_bit_index) & 1;
                const sprite_color_index = (sbit1 << 1) | sbit0;

                if (sprite_color_index != 0) {
                    self.registers.status.sprite0_hit = true;
                }
            }
        }

        const attr_table_base = self.registers.scroll_unit.v.read() & 0x0C00;
        const attr_x = tile_x / 4;
        const attr_y = tile_y / 4;
        const attr_index = attr_y * 8 + attr_x;
        const attr_byte = self.vram.memory[attr_table_base + @as(u16, attr_index)];

        const offset_y = (tile_y % 4) / 2;
        const offset_x = (tile_x % 4) / 2;
        const shift: u3 = @intCast((offset_y * 2 + offset_x) * 2);
        const palette_number = (attr_byte >> shift) & 0b11;

        const palette_index = self.vram.readPalette(@as(u16, 0x3F00) + @as(u16, palette_number) * 4 + @as(u16, color_index));
        const color = NES_PALETTE[palette_index];

        fb.setPixel(@intCast(x), @intCast(y), color);
    }

    pub fn writeRegister(self: *PPU, reg: u3, value: u8) void {
        self.open_bus = value;
        self.open_bus_decay_counter = 0; // Reset decay counter on write

        switch (reg) {
            0 => self.writeCtrl(value),
            1 => self.writeMask(value),
            2 => {}, // read-only
            3 => self.writeOamAddr(value),
            4 => self.writeOamData(value),
            // 5 => self.registers.scroll_unit.writeScroll(value),
            5 => self.writeScroll(value),
            6 => self.registers.scroll_unit.writeAddr(value),
            7 => self.writeData(value),
        }
    }

    pub fn readRegister(self: *PPU, reg: u3) u8 {
        return switch (reg) {
            2 => return self.readStatus(),
            4 => return self.readOamData(),
            7 => return self.readData(),
            else => self.open_bus, // Open bus for other registers
        };
    }

    fn writeCtrl(self: *PPU, value: u8) void {
        self.registers.ctrl = value;
    }

    fn writeMask(self: *PPU, value: u8) void {
        self.registers.mask.write(value);
    }

    fn writeOamAddr(self: *PPU, value: u8) void {
        self.registers.oam_addr = value;
    }

    pub fn writeOamData(self: *PPU, value: u8) void {
        self.registers.oam_data[self.registers.oam_addr] = value;
        self.registers.oam_addr +%= 1;
    }

    fn writeScroll(self: *PPU, value: u8) void {
        self.registers.scroll_unit.writeScroll(value);
    }

    fn writeData(self: *PPU, value: u8) void {
        const addr = self.registers.scroll_unit.v.read() & 0x3FFF;
        if (addr < 0x2000) {
            self.cartridge.writeCHR(addr, value);
            // return; // CHR ROM/RAM write
        } else if (addr >= 0x2000 and addr < 0x3F00) {
            self.vram.write(addr, value);
        } else if (addr >= 0x3F00 and addr < 0x4000) {
            self.vram.writePalette(addr, value);
        }

        if ((self.registers.ctrl >> 2) & 0b1 == 1) {
            const new_addr = (self.registers.scroll_unit.v.read() + 32) & 0x7FFF;
            self.registers.scroll_unit.v.write(new_addr);
        } else {
            const new_addr = (self.registers.scroll_unit.v.read() + 1) & 0x7FFF;
            self.registers.scroll_unit.v.write(new_addr);
        }
    }

    fn readData(self: *PPU) u8 {
        const addr = self.registers.scroll_unit.v.read() & 0x3FFF;
        var result: u8 = 0;

        if (addr < 0x2000) {
            result = self.vram.buffer;
            self.vram.buffer = self.cartridge.readCHR(addr);
            self.open_bus = result;
        } else if (addr < 0x3F00) {
            result = self.vram.buffer;
            self.vram.buffer = self.vram.read(addr);
            self.open_bus = result;
        } else if (addr < 0x4000) {
            const palette = self.vram.readPalette(addr);
            const high2 = self.open_bus & 0b1100_0000;
            result = high2 | (palette & 0b0011_1111);
        }

        if ((self.registers.ctrl >> 2) & 0b1 == 1) {
            self.registers.scroll_unit.incrementVertical();
        } else {
            self.registers.scroll_unit.incrementHorizontal();
        }

        return result;
    }

    fn readStatus(self: *PPU) u8 {
        const status = self.registers.status;
        const low5 = self.open_bus & 0b0001_1111;
        const high3: u8 =
            (@as(u8, @intFromBool(status.vblank)) << 7) |
            (@as(u8, @intFromBool(status.sprite0_hit)) << 6) |
            (@as(u8, @intFromBool(status.sprite_overflow)) << 5);

        const result = high3 | low5;

        self.open_bus = result;
        self.registers.scroll_unit.resetLatch();
        self.registers.status.vblank = false;

        return result;
    }

    fn readOamData(self: *PPU) u8 {
        const index = self.registers.oam_addr;
        if (index % 4 == 2) {
            const raw = self.registers.oam_data[index];
            self.open_bus = raw & 0b1110_0011; // Clear unused bits
        } else {
            self.open_bus = self.registers.oam_data[index];
        }

        return self.open_bus; // Return OAM data
    }

    fn incrementVRAMAddress(self: *PPU) void {
        if ((self.registers.ctrl >> 2) & 0b1 == 1) {
            self.registers.scroll_unit.incrementVertical();
        } else {
            self.registers.scroll_unit.incrementHorizontal();
        }
    }
};
