const std = @import("std");
const Bus = @import("bus.zig").Bus;
const Cartridge = @import("cartridge.zig").Cartridge;
const Mirroring = @import("cartridge.zig").Mirroring;
const sdl = @import("sdl.zig");

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
    memory: [0x800]u8 = [_]u8{0} ** 0x800,
    palette: [32]u8 = [_]u8{0} ** 32,
    buffer: u8 = 0, // Buffer for PPU data reads
    mirroring: Mirroring,

    pub fn init(mirroring: Mirroring) VRAM {
        var vram = VRAM{
            .memory = [_]u8{0} ** 0x800,
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
            self.memory[mirrored] = value;
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

const Mask = packed struct {
    grayscale: bool,
    show_bg_left: bool,
    show_sprites_left: bool,
    show_bg: bool,
    show_sprites: bool,
    emphasize_red: bool,
    emphasize_green: bool,
    emphasize_blue: bool,

    pub fn read(self: Mask) u8 {
        return @bitCast(self);
    }

    pub fn write(self: *Mask, value: u8) void {
        self.* = @bitCast(value);
    }
};

const Status = packed struct {
    unused: u5 = 0,
    sprite_overflow: bool,
    sprite0_hit: bool,
    vblank: bool = false,

    pub fn read(self: *Status) u8 {
        const result: u8 = @bitCast(self.*);
        self.vblank = false;
        return result;
    }
};

const Ctrl = packed struct {
    nametable: u2 = 0, // 0: $2000, 1: $2400, 2: $2800, 3: $2C00
    vram_increment: u1 = 0, // 0: increment by 1, 1: increment by 32
    sprite_table: u1 = 0, // 0: 8x8 sprites, 1: 8x16 sprites
    background_table: u1 = 0, // 0: $0000, 1: $1000
    sprite_size: u1 = 0, // 0: 8x8 sprites, 1: 8x16 sprites
    master_slave: u1 = 0, // 0: PPU is master, 1: PPU is slave
    generate_nmi: u1 = 0, // 0: no NMI, 1: generate NMI on VBlank

    pub fn read(self: Ctrl) u8 {
        return @bitCast(self);
    }

    pub fn write(self: *Ctrl, value: u8) void {
        self.* = @bitCast(value);
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
    ctrl: Ctrl = .{}, // $2000
    mask: Mask = @bitCast(@as(u8, 0)), // $2001
    status: Status = @bitCast(@as(u8, 0)), // $2002
    oam_addr: u8 = 0, // $2003
    oam_data: [256]u8 = [_]u8{0} ** 256, // $2004
    scroll_unit: ScrollUnit = .{}, // $2005 + $2006 + fine X scroll
};

// Open bus decay timing for each bit
// Based on Visual 2C02 analysis: different bits decay at different rates
const OpenBusDecay = struct {
    data: u8 = 0,
    // Each bit has its own decay timer (in PPU cycles)
    // bit 7-5: ~600000 cycles (10 seconds at 60Hz)
    // bit 4: ~300000 cycles (5 seconds)
    // bit 3-0: ~180000 cycles (3 seconds)
    bit_timers: [8]u32 = [_]u32{0} ** 8,

    const DECAY_CYCLES_LOW = 180000; // bits 3-0
    const DECAY_CYCLES_MID = 300000; // bit 4
    const DECAY_CYCLES_HIGH = 600000; // bits 7-5

    pub fn write(self: *OpenBusDecay, value: u8) void {
        self.data = value;
        // Reset all bit timers on write
        self.bit_timers = [_]u32{0} ** 8;
    }

    pub fn read(self: *OpenBusDecay) u8 {
        return self.data;
    }

    pub fn tick(self: *OpenBusDecay) void {
        // Increment timers for each bit
        for (0..8) |i| {
            self.bit_timers[i] += 1;

            // Check if bit should decay
            const decay_threshold: u32 = if (i <= 3)
                DECAY_CYCLES_LOW
            else if (i == 4)
                DECAY_CYCLES_MID
            else
                DECAY_CYCLES_HIGH;

            if (self.bit_timers[i] >= decay_threshold) {
                // Clear the bit
                self.data &= ~(@as(u8, 1) << @intCast(i));
            }
        }
    }

    pub fn refresh_bits(self: *OpenBusDecay, value: u8, mask: u8) void {
        // Refresh specific bits and reset their timers
        self.data = (self.data & ~mask) | (value & mask);

        // Reset timers for refreshed bits
        for (0..8) |i| {
            if ((mask >> @intCast(i)) & 1 == 1) {
                self.bit_timers[i] = 0;
            }
        }
    }
};

pub const PPU = struct {
    registers: Registers,
    vram: VRAM,
    _vblank_injected: bool = false,

    cycle: u16 = 0,
    scanline: i16 = -1, // -1 (pre-render) 〜 260 (vblank)
    frame: usize = 0,
    cartridge: *Cartridge,
    open_bus: OpenBusDecay = .{}, // Open bus with proper decay
    dma_active: bool = false,

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

    pub fn init(cartridge: *Cartridge) PPU {
        return PPU{
            .registers = .{},
            .vram = VRAM.init(cartridge.mirroring),
            ._vblank_injected = false,
            .cycle = 0,
            .scanline = -1, // Start at pre-render line
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

        // Pre-render scanline (-1)
        if (self.scanline == -1 and self.cycle == 1) {
            self.registers.status.vblank = false;
            self._vblank_injected = false;
            self.registers.status.sprite0_hit = false; // Reset sprite 0 hit flag
            self.registers.status.sprite_overflow = false; // Reset sprite overflow flag

        }

        // At cycle 280-304 of pre-render scanline, copy vertical scroll bits from t to v
        if (self.scanline == -1 and self.cycle >= 280 and self.cycle <= 304) {
            if (self.registers.mask.show_bg or self.registers.mask.show_sprites) {
                // Copy vertical scroll bits: v: GHIA.BC DEF..... <- t: GHIA.BC DEF.....
                const v = self.registers.scroll_unit.v.read();
                const t = self.registers.scroll_unit.t.read();
                const new_v = (v & 0x041F) | (t & 0x7BE0);
                self.registers.scroll_unit.v.write(new_v);
            }
        }

        // Update horizontal scroll at the end of each visible scanline
        if (self.scanline >= 0 and self.scanline < 240 and self.cycle == 256) {
            // This is where horizontal scroll would reset and vertical scroll would increment
            // For now, we're using simplified rendering
        }

        self.cycle += 1;
        if (self.cycle > 340) {
            self.cycle = 0;
            self.scanline += 1;

            // After scanline 260, wrap to -1 (pre-render)
            if (self.scanline > 260) {
                self.scanline = -1;
                self.frame += 1;
            }
        }

        // Tick open bus decay every cycle
        self.open_bus.tick();
    }

    pub fn isFrameComplete(self: *PPU) bool {
        // Frame is complete when we transition from scanline 260 to -1
        return self.scanline == -1 and self.cycle == 0;
    }

    pub fn renderPixel(self: *PPU, fb: *FrameBuffer) !void {
        if (self.cartridge.chr_rom.len == 0) return;

        // Don't render if PPU rendering is disabled
        if (!self.registers.mask.show_bg and !self.registers.mask.show_sprites) return;

        const x: u16 = @intCast(self.cycle - 1);
        const y: u16 = @intCast(self.scanline);

        // Get the current VRAM address (includes scroll information)
        const v = self.registers.scroll_unit.v.read();

        // Extract scroll position from v register
        const v_nametable = (v >> 10) & 0x03;

        // For simplified rendering, we'll use screen coordinates
        const tile_x = x / 8;
        const tile_y = y / 8;

        // Get nametable from current vram address
        const nametable_select = v_nametable;
        const nametable_base = 0x2000 + @as(u16, nametable_select) * 0x400;

        const name_table_index = tile_y * 32 + tile_x;
        const tile_id = self.vram.read(nametable_base + name_table_index);

        const pixel_x: u3 = @intCast(x % 8);
        const pixel_y: u3 = @intCast(y % 8);

        const bg_table_addr: usize = if (self.registers.ctrl.background_table == 0) 0x0000 else 0x1000;
        const chr_index = bg_table_addr + @as(usize, tile_id) * 16;

        // Bounds check for CHR ROM access
        if (chr_index + 8 + pixel_y >= self.cartridge.chr_rom.len) return;

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
                const sprite_table_addr: usize = if (self.registers.ctrl.sprite_table == 0) 0x0000 else 0x1000;
                const sprite_chr_index = sprite_table_addr + @as(usize, sprite_tile) * 16;

                // Bounds check for sprite CHR ROM access
                if (sprite_chr_index + 8 + sprite_pixel_y >= self.cartridge.chr_rom.len) return;

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

        const attr_index = (tile_y / 4) * 8 + (tile_x / 4);
        const attr_addr = nametable_base + 0x03C0 + @as(u16, attr_index);
        const attr_byte = self.vram.read(attr_addr);

        const offset_y = (tile_y % 4) / 2;
        const offset_x = (tile_x % 4) / 2;
        const shift: u3 = @intCast((offset_y * 2 + offset_x) * 2);
        const palette_number = (attr_byte >> shift) & 0b11;

        const palette_addr: u16 = 0x3F00 + @as(u16, palette_number) * 4 + @as(u16, color_index);
        const palette_index = self.vram.readPalette(palette_addr) & 0x3F; // Mask to 6 bits
        const color = sdl.NES_PALETTE[palette_index];

        fb.setPixel(@intCast(x), @intCast(y), color);
    }

    pub fn writeRegister(self: *PPU, reg: u3, value: u8) void {
        // All writes refresh the full open bus
        self.open_bus.write(value);

        switch (reg) {
            0 => self.writeCtrl(value),
            1 => self.writeMask(value),
            2 => {}, // read-only
            3 => self.writeOamAddr(value),
            4 => self.writeOamData(value),
            5 => self.writeScroll(value),
            6 => self.writeAddr(value),
            7 => self.writeData(value),
        }
    }

    pub fn readRegister(self: *PPU, reg: u3) u8 {
        return switch (reg) {
            2 => self.readStatus(),
            4 => self.readOamData(),
            7 => self.readData(),
            else => self.open_bus.read(), // Open bus for write-only registers
        };
    }

    fn writeCtrl(self: *PPU, value: u8) void {
        const prev_nmi_output = self.registers.ctrl.generate_nmi;
        self.registers.ctrl.write(value);
        self.registers.scroll_unit.t.nametable = @truncate(value & 0b0000_0011);
        const new_nmi_output = self.registers.ctrl.generate_nmi;

        if (prev_nmi_output == 0 and new_nmi_output == 1 and self.registers.status.vblank) {
            self.registers.ctrl.generate_nmi = 1;
        }

        if (prev_nmi_output == 1 and new_nmi_output == 0) {
            self.registers.ctrl.generate_nmi = 0;
        }
    }

    fn writeMask(self: *PPU, value: u8) void {
        self.registers.mask.write(value);
    }

    fn writeOamAddr(self: *PPU, value: u8) void {
        self.registers.oam_addr = value;
    }

    pub fn writeOamData(self: *PPU, value: u8) void {
        var data = value;
        // If writing to attribute byte (byte 2 of each sprite), clear bits 2-4
        if (self.registers.oam_addr % 4 == 2) {
            data &= 0b1110_0011; // Clear bits 2-4
        }
        self.registers.oam_data[self.registers.oam_addr] = data;
        self.registers.oam_addr +%= 1;
    }

    fn writeScroll(self: *PPU, value: u8) void {
        self.registers.scroll_unit.writeScroll(value);
    }

    fn writeAddr(self: *PPU, value: u8) void {
        self.registers.scroll_unit.writeAddr(value);
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

        self.incrementVRAMAddress();
    }

    fn readData(self: *PPU) u8 {
        const addr = self.registers.scroll_unit.v.read() & 0x3FFF;
        var result: u8 = 0;

        if (addr < 0x2000) {
            // CHR ROM/RAM: buffered read
            result = self.vram.buffer;
            self.vram.buffer = self.cartridge.readCHR(addr);
            self.open_bus.write(result); // Full refresh
        } else if (addr < 0x3F00) {
            // Nametable: buffered read
            result = self.vram.buffer;
            self.vram.buffer = self.vram.read(addr);
            self.open_bus.write(result); // Full refresh
        } else if (addr < 0x4000) {
            // Palette: immediate read, partial refresh
            const palette = self.vram.readPalette(addr);
            // Keep high 2 bits from open bus, refresh low 6 bits
            result = (self.open_bus.read() & 0b1100_0000) | (palette & 0b0011_1111);
            self.open_bus.refresh_bits(palette, 0b0011_1111); // Only refresh low 6 bits
        }

        self.incrementVRAMAddress();
        return result;
    }

    fn readStatus(self: *PPU) u8 {
        const status = self.registers.status;
        // Keep low 5 bits from open bus
        const low5 = self.open_bus.read() & 0b0001_1111;
        const high3: u8 =
            (@as(u8, @intFromBool(status.vblank)) << 7) |
            (@as(u8, @intFromBool(status.sprite0_hit)) << 6) |
            (@as(u8, @intFromBool(status.sprite_overflow)) << 5);

        const result = high3 | low5;

        // Only refresh the high 3 bits
        self.open_bus.refresh_bits(high3, 0b1110_0000);
        self.registers.scroll_unit.resetLatch();
        self.registers.status.vblank = false;

        return result;
    }

    fn readOamData(self: *PPU) u8 {
        const index = self.registers.oam_addr;
        var result: u8 = 0;

        if (index % 4 == 2) {
            // Attribute byte: bits 2-4 should always read as 0
            const oam_data = self.registers.oam_data[index];
            result = oam_data & 0b1110_0011; // Clear bits 2-4
            // Refresh open bus with the result
            self.open_bus.write(result);
        } else {
            result = self.registers.oam_data[index];
            self.open_bus.write(result); // Full refresh
        }

        return result;
    }

    fn incrementVRAMAddress(self: *PPU) void {
        const increment: u16 = if (self.registers.ctrl.vram_increment == 1) 32 else 1;
        const old_addr = self.registers.scroll_unit.v.read();
        const new_addr = (old_addr + increment) & 0x7FFF;

        self.registers.scroll_unit.v.write(new_addr);
    }
};
