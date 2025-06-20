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
        return VRAM{
            .memory = [_]u8{0} ** 0x800,
            .palette = [_]u8{0x0F} ** 32, // Initialize with black (0x0F)
            .mirroring = mirroring,
        };
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

const SpriteAttribute = packed struct {
    palette: u2,
    unused: u3 = 0,
    priority: u1, // 0: in front of background, 1: behind background
    flip_h: u1,
    flip_v: u1,

    pub fn read(self: SpriteAttribute) u8 {
        return @bitCast(self);
    }

    pub fn write(self: *SpriteAttribute, value: u8) void {
        self.* = @bitCast(value & 0b1110_0011); // Clear unused bits
    }
};

const Sprite = struct {
    y: u8,
    tile_index: u8,
    attributes: SpriteAttribute,
    x: u8,
};

const OAM = struct {
    data: [256]u8 = [_]u8{0} ** 256,

    pub fn getSprite(self: *const OAM, index: u8) Sprite {
        const offset = @as(usize, index) * 4;
        return Sprite{
            .y = self.data[offset],
            .tile_index = self.data[offset + 1],
            .attributes = @bitCast(self.data[offset + 2]),
            .x = self.data[offset + 3],
        };
    }

    pub fn setSprite(self: *OAM, index: u8, sprite: Sprite) void {
        const offset = @as(usize, index) * 4;
        self.data[offset] = sprite.y;
        self.data[offset + 1] = sprite.tile_index;
        self.data[offset + 2] = sprite.attributes.read();
        self.data[offset + 3] = sprite.x;
    }
};

const Registers = struct {
    ctrl: Ctrl = .{}, // $2000
    mask: Mask = @bitCast(@as(u8, 0)), // $2001
    status: Status = @bitCast(@as(u8, 0x80)), // $2002 - Start with VBlank set
    oam_addr: u8 = 0, // $2003
    oam: OAM = .{}, // $2004 - OAM data
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

// Secondary OAM for sprite evaluation
const SecondaryOAM = struct {
    sprites: [8]Sprite = undefined,
    sprite_indices: [8]u8 = undefined, // Keep track of original sprite indices for sprite 0 hit
    count: u8 = 0,

    pub fn clear(self: *SecondaryOAM) void {
        self.count = 0;
    }

    pub fn addSprite(self: *SecondaryOAM, sprite: Sprite, index: u8) bool {
        if (self.count >= 8) return false;
        self.sprites[self.count] = sprite;
        self.sprite_indices[self.count] = index;
        self.count += 1;
        return true;
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
    secondary_oam: SecondaryOAM = .{},

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
            .scanline = -1,
            .frame = 0,
            .cartridge = cartridge,
        };
    }

    pub fn step(self: *PPU, fb: *FrameBuffer) !void {
        // Sprite evaluation happens at cycle 65-256 of visible scanlines
        if (self.scanline >= 0 and self.scanline < 240) {
            if (self.cycle == 65) {
                // Clear secondary OAM and evaluate sprites for the current scanline
                self.secondary_oam.clear();
                self.evaluateSprites(@intCast(self.scanline));
            }
        }

        if (self.scanline >= 0 and self.scanline < 240 and self.cycle >= 1 and self.cycle <= 256) {
            try self.renderPixel(fb);

            // Increment horizontal scroll every 8 pixels during rendering
            if ((self.cycle - 1) % 8 == 7 and (self.registers.mask.show_bg or self.registers.mask.show_sprites)) {
                self.registers.scroll_unit.incrementHorizontal();
            }
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
            if (self.registers.mask.show_bg or self.registers.mask.show_sprites) {
                // Increment vertical scroll
                self.registers.scroll_unit.incrementVertical();
            }
        }

        // Reset horizontal scroll at the end of each scanline
        if (self.scanline >= -1 and self.scanline < 240 and self.cycle == 257) {
            if (self.registers.mask.show_bg or self.registers.mask.show_sprites) {
                // Copy horizontal bits from t to v: v: ....A.. ...BCDEF <- t: ....A.. ...BCDEF
                const v = self.registers.scroll_unit.v.read();
                const t = self.registers.scroll_unit.t.read();
                const new_v = (v & 0x7BE0) | (t & 0x041F);
                self.registers.scroll_unit.v.write(new_v);
            }
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
        // if (self.cartridge.chr_rom.len == 0) return;

        // Don't render if PPU rendering is disabled
        if (!self.registers.mask.show_bg and !self.registers.mask.show_sprites) return;

        const x: u16 = @intCast(self.cycle - 1);
        const y: u16 = @intCast(self.scanline);

        var bg_color_index: u2 = 0;
        var bg_palette_index: u8 = 0;

        // Render background pixel
        if (self.registers.mask.show_bg and (x >= 8 or self.registers.mask.show_bg_left)) {
            // Get the current VRAM address (includes scroll information)
            const v = self.registers.scroll_unit.v.read();

            // Extract scroll components from v register
            const coarse_x = v & 0x1F;
            const coarse_y = (v >> 5) & 0x1F;
            const nametable_x = (v >> 10) & 0x01;
            const nametable_y = (v >> 11) & 0x01;
            const fine_y = (v >> 12) & 0x07;

            // Calculate tile coordinates
            const tile_x = coarse_x;
            const tile_y = coarse_y;

            // Get nametable base address
            const nametable_select = (nametable_y << 1) | nametable_x;
            const nametable_base = 0x2000 + @as(u16, nametable_select) * 0x400;

            const name_table_index = tile_y * 32 + tile_x;
            const tile_id = self.vram.read(nametable_base + name_table_index);

            // Calculate pixel position within the tile
            // We need to consider both the fine X scroll and the current pixel position
            const current_pixel = (self.cycle - 1) % 8;
            const pixel_x: u3 = @intCast((current_pixel + self.registers.scroll_unit.x) & 0x07);
            const pixel_y: u3 = @intCast(fine_y);

            const bg_table_addr: usize = if (self.registers.ctrl.background_table == 0) 0x0000 else 0x1000;
            const chr_index = bg_table_addr + @as(usize, tile_id) * 16;

            // Bounds check for CHR ROM access
            if (chr_index + 8 + pixel_y < self.cartridge.chr_rom.len) {
                const plane0 = self.cartridge.chr_rom[chr_index + pixel_y];
                const plane1 = self.cartridge.chr_rom[chr_index + 8 + pixel_y];

                const bit_index: u3 = 7 - pixel_x;
                const bit0 = (plane0 >> bit_index) & 1;
                const bit1 = (plane1 >> bit_index) & 1;
                bg_color_index = @intCast((bit1 << 1) | bit0);

                // Get attribute byte for palette selection
                const attr_x = tile_x / 4;
                const attr_y = tile_y / 4;
                const attr_index = attr_y * 8 + attr_x;
                const attr_addr = nametable_base + 0x03C0 + @as(u16, attr_index);
                const attr_byte = self.vram.read(attr_addr);

                const quad_x = (tile_x % 4) / 2;
                const quad_y = (tile_y % 4) / 2;
                const shift: u3 = @intCast((quad_y * 2 + quad_x) * 2);
                const palette_number = (attr_byte >> shift) & 0b11;
                bg_palette_index = @intCast(palette_number);
            }
        }

        // Variables for sprite rendering
        var sprite_color_index: u2 = 0;
        var sprite_palette_index: u8 = 0;
        var sprite_priority: u1 = 0;
        var sprite_is_zero = false;

        // Render sprite pixel
        if (self.registers.mask.show_sprites and (x >= 8 or self.registers.mask.show_sprites_left)) {
            // Check each sprite in secondary OAM
            for (0..self.secondary_oam.count) |i| {
                const sprite = self.secondary_oam.sprites[i];
                const sprite_index = self.secondary_oam.sprite_indices[i];

                // Check if sprite covers this pixel
                // Use wrapping arithmetic to handle sprites at screen edges
                const sprite_end_x = sprite.x +% 8;
                const sprite_visible = if (sprite_end_x > sprite.x)
                    (x >= sprite.x and x < sprite_end_x)
                else
                    (x >= sprite.x or x < sprite_end_x); // Sprite wraps around screen

                if (sprite_visible) {
                    // In NES, sprite Y is the actual Y coordinate minus 1
                    const sprite_y_actual = sprite.y +% 1;

                    // Check if current scanline is within sprite bounds
                    if (y < sprite_y_actual or y >= sprite_y_actual +% 8) continue;

                    const sprite_pixel_x_temp = x -% sprite.x;
                    const sprite_pixel_y_temp = y -% sprite_y_actual;

                    // Ensure values are within valid range (should be guaranteed by checks above)
                    if (sprite_pixel_x_temp >= 8 or sprite_pixel_y_temp >= 8) continue;

                    var sprite_pixel_x: u3 = @intCast(sprite_pixel_x_temp);
                    var sprite_pixel_y: u3 = @intCast(sprite_pixel_y_temp);

                    // Apply horizontal flip
                    if (sprite.attributes.flip_h == 1) {
                        sprite_pixel_x = 7 - sprite_pixel_x;
                    }

                    // Apply vertical flip
                    if (sprite.attributes.flip_v == 1) {
                        sprite_pixel_y = 7 - sprite_pixel_y;
                    }

                    const sprite_table_addr: usize = if (self.registers.ctrl.sprite_table == 0) 0x0000 else 0x1000;
                    const sprite_chr_index = sprite_table_addr + @as(usize, sprite.tile_index) * 16;

                    // Bounds check for sprite CHR ROM access
                    if (sprite_chr_index + 8 + sprite_pixel_y < self.cartridge.chr_rom.len) {
                        const sprite_plane0 = self.cartridge.chr_rom[sprite_chr_index + sprite_pixel_y];
                        const sprite_plane1 = self.cartridge.chr_rom[sprite_chr_index + 8 + sprite_pixel_y];

                        const sprite_bit_index: u3 = 7 - sprite_pixel_x;
                        const sbit0 = (sprite_plane0 >> sprite_bit_index) & 1;
                        const sbit1 = (sprite_plane1 >> sprite_bit_index) & 1;
                        const color = @as(u2, @intCast((sbit1 << 1) | sbit0));

                        // If pixel is not transparent, use this sprite
                        if (color != 0 and sprite_color_index == 0) {
                            sprite_color_index = color;
                            sprite_palette_index = sprite.attributes.palette;
                            sprite_priority = sprite.attributes.priority;
                            sprite_is_zero = (sprite_index == 0);
                        }
                    }
                }
            }
        }

        // Determine which pixel to render (sprite or background)
        var final_color_index: u2 = 0;
        var final_palette_addr: u16 = 0;

        // Sprite 0 hit detection
        if (!self.registers.status.sprite0_hit and sprite_is_zero and
            bg_color_index != 0 and sprite_color_index != 0 and
            x < 255 and self.registers.mask.show_bg and self.registers.mask.show_sprites)
        {
            self.registers.status.sprite0_hit = true;
        }

        // Priority logic
        if (bg_color_index == 0 and sprite_color_index == 0) {
            // Both transparent, use backdrop color
            final_palette_addr = 0x3F00;
        } else if (bg_color_index == 0 and sprite_color_index != 0) {
            // Background transparent, show sprite
            final_color_index = sprite_color_index;
            final_palette_addr = 0x3F10 + @as(u16, sprite_palette_index) * 4 + @as(u16, sprite_color_index);
        } else if (bg_color_index != 0 and sprite_color_index == 0) {
            // Sprite transparent, show background
            final_color_index = bg_color_index;
            final_palette_addr = 0x3F00 + @as(u16, bg_palette_index) * 4 + @as(u16, bg_color_index);
        } else {
            // Both opaque, check priority
            if (sprite_priority == 0) {
                // Sprite in front
                final_color_index = sprite_color_index;
                final_palette_addr = 0x3F10 + @as(u16, sprite_palette_index) * 4 + @as(u16, sprite_color_index);
            } else {
                // Background in front
                final_color_index = bg_color_index;
                final_palette_addr = 0x3F00 + @as(u16, bg_palette_index) * 4 + @as(u16, bg_color_index);
            }
        }

        // Get final color from palette
        const palette_index = self.vram.readPalette(final_palette_addr) & 0x3F;
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
        self.registers.oam.data[self.registers.oam_addr] = data;
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
            const oam_data = self.registers.oam.data[index];
            result = oam_data & 0b1110_0011; // Clear bits 2-4
            // Refresh open bus with the result
            self.open_bus.write(result);
        } else {
            result = self.registers.oam.data[index];
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

    pub fn evaluateSprites(self: *PPU, scanline: u8) void {
        const sprite_height: u8 = if (self.registers.ctrl.sprite_size == 0) 8 else 16;

        // Evaluate all 64 sprites
        for (0..64) |i| {
            const sprite = self.registers.oam.getSprite(@intCast(i));

            // Check if sprite is on this scanline
            // In NES, sprite Y is the actual Y coordinate minus 1
            const sprite_y_actual = sprite.y +% 1;

            // Skip sprites with Y = 255 (effectively Y = 0 after +1, which hides the sprite)
            if (sprite.y >= 0xEF) continue;

            if (scanline >= sprite_y_actual and scanline < sprite_y_actual +% sprite_height) {
                if (!self.secondary_oam.addSprite(sprite, @intCast(i))) {
                    // Set sprite overflow flag if we can't add more sprites
                    self.registers.status.sprite_overflow = true;
                    break;
                }
            }
        }
    }
};
