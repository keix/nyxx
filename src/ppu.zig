const std = @import("std");
const Bus = @import("bus.zig").Bus;
const Cartridge = @import("cartridge.zig").Cartridge;

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

// const LoopyRegister = struct {
//     coarse_x: u5 = 0, // Coarse X scroll (0-31)
//     coarse_y: u5 = 0, // Coarse Y scroll (0-29)
//     nametable: u2 = 0, // Nametable select (0-3)
//     fine_y: u3 = 0, // Fine Y scroll (0-7)
//     unused: u1 = 0, // Unused bit

//     pub fn read(self: LoopyRegister) u16 {
//         return (@as(u16, self.fine_y) << 12) |
//             (@as(u16, self.nametable) << 10) |
//             (@as(u16, self.coarse_y) << 5) |
//             (@as(u16, self.coarse_x));
//     }

//     pub fn write(self: *LoopyRegister, value: u16) void {
//         self.coarse_x = @truncate(value & 0b00000_00000_00011111);
//         self.coarse_y = @truncate((value >> 5) & 0b00000_00000_00011111);
//         self.nametable = @truncate((value >> 10) & 0b00000_00000_00000011);
//         self.fine_y = @truncate((value >> 12) & 0b00000_00000_00000111);
//     }
// };

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
        std.debug.print("writeAddr: t=0x{X:0>4} v=0x{X:0>4} w={}\n", .{ self.t.read(), self.v.read(), self.w });
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
    vram_buffer: u8 = 0, // $2007
};

pub const PPU = struct {
    registers: Registers = .{},
    vram: [0x4000]u8 = [_]u8{0} ** 0x4000, // VRAM
    palette_table: [32]u8 = [_]u8{0} ** 32,
    _vblank_injected: bool = false,

    // step 管理用
    cycle: u16 = 0,
    scanline: i16 = 0, // -1 (pre-render) 〜 260 (post-render)
    frame: usize = 0,
    cartridge: *const Cartridge,

    pub fn dumpNameTable(self: *PPU) void {
        const start = 0x2000;
        const end = 0x23C0;
        for (start..end) |addr| {
            if ((addr - start) % 32 == 0) {
                std.debug.print("\n0x{X:04}: ", .{addr});
            }
            std.debug.print("{X:02} ", .{self.vram[addr]});
        }
        std.debug.print("\n", .{});
    }

    pub fn init(cartridge: *const Cartridge) PPU {
        var ppu = PPU{
            .registers = .{},
            .vram = [_]u8{0} ** 0x4000,
            .palette_table = [_]u8{0} ** 32,
            ._vblank_injected = false,
            .cycle = 0,
            .scanline = -1, // pre-render line
            .frame = 0,
            .cartridge = cartridge,
        };
        //}

        // pub fn setCartridge(self: *PPU, cartridge: *const Cartridge) void {
        // PPU の初期化時にパレットテーブルを設定
        //self.cartridge = cartridge;
        ppu.palette_table = [_]u8{
            0x01, 0x23, 0x27, 0x30, // BG Palette 0
            0x0F, 0x2D, 0x3A, 0x12, // BG Palette 1
            0x1C, 0x2B, 0x3C, 0x0A, // BG Palette 2
            0x1E, 0x2E, 0x3E, 0x0C, // BG Palette 3
            0x0F, 0x3D, 0x2C, 0x1A, // Sprite Palette 0
            0x1D, 0x2F, 0x3F, 0x0B, // Sprite Palette 1
            0x0E, 0x3E, 0x2A, 0x09, // Sprite Palette 2
            0x1F, 0x2D, 0x3B, 0x0D, // Sprite Palette 3
        };

        // 32列 × 30行 = 960バイト
        for (0..30) |row| {
            for (0..32) |col| {
                const index = row * 32 + col;
                // ppu.vram[0x2000 + index] = @truncate(index); // 適当なtile_idを並べる
                ppu.vram[0x2000 + index] = @truncate((row + col) % 64); // タイルIDをパターン化

            }
        }

        return ppu;
    }

    pub fn step(self: *PPU, fb: *FrameBuffer) !void {
        // 可視領域内ピクセルレンダリング
        if (self.scanline >= 0 and self.scanline < 240 and self.cycle >= 1 and self.cycle <= 256) {
            try self.renderPixel(fb);
        }

        // VBlank 開始タイミング
        if (self.scanline == 241 and self.cycle == 1) {
            self.registers.status.vblank = true;
        }

        // pre-render line
        if (self.scanline == 261 and self.cycle == 1) {
            self.registers.status.vblank = false;
            self._vblank_injected = false;
        }

        // クロック更新
        self.cycle += 1;
        if (self.cycle > 340) {
            self.cycle = 0;
            self.scanline += 1;
            if (self.scanline > 261) {
                self.scanline = 0;
                self.frame += 1;
            }
        }
    }

    pub fn isFrameComplete(self: *PPU) bool {
        return self.scanline == 0 and self.cycle == 0;
    }

    fn renderPixel(self: *PPU, fb: *FrameBuffer) !void {
        // const stdout = std.io.getStdOut().writer();

        const x = self.cycle - 1;
        const y = self.scanline;

        const ux: u16 = @intCast(x);
        const uy: u16 = @intCast(y);

        const tile_x = ux / 8;
        const tile_y = uy / 8;
        const name_table_index = tile_y * 32 + tile_x;

        const tile_id = self.vram[0x2000 + name_table_index];

        const pixel_x_in_tile: u3 = @intCast(ux % 8);
        const pixel_y_in_tile: u3 = @intCast(uy % 8);

        const chr_index: usize = @as(usize, tile_id) * 16;
        const plane0 = self.cartridge.chr_rom[chr_index + pixel_y_in_tile];
        const plane1 = self.cartridge.chr_rom[chr_index + 8 + pixel_y_in_tile];

        const bit_index: u3 = 7 - pixel_x_in_tile;
        const bit0 = (plane0 >> bit_index) & 1;
        const bit1 = (plane1 >> bit_index) & 1;

        const color_index = (bit1 << 1) | bit0;

        const x_u8: u8 = @intCast(ux);
        const y_u8: u8 = @intCast(uy);

        // const palette_index = self.palette_table[color_index];
        // const palette_index = self.palette_table[0 * 4 + color_index]; // 一旦 Palette 0 固定

        const attr_table_base: usize = 0x23C0;
        const attr_x = tile_x / 4;
        const attr_y = tile_y / 4;
        const attr_index = attr_y * 8 + attr_x;
        const attr_byte = self.vram[attr_table_base + attr_index];

        // タイル内の 2x2 ブロックの中での位置
        // const shift = @as(u3, ((tile_y % 4) / 2) * 2 + ((tile_x % 4) / 2)) * 2;
        const offset_y = (tile_y % 4) / 2;
        const offset_x = (tile_x % 4) / 2;
        const shift: u3 = @intCast((offset_y * 2 + offset_x) * 2);
        const palette_number = (attr_byte >> shift) & 0b11;

        // const palette_number = (tile_x / 8 + tile_y / 8) % 4;
        const palette_index = self.palette_table[palette_number * 4 + color_index];
        const color = NES_PALETTE[palette_index];

        if (uy == 0) {
            // try stdout.print("xy=({},{}) tile_id={} px=({}, {}) idx={} colors=({}, {}) -> ci={} pi={} color=0x{X:0>6}\n", .{ ux, uy, tile_id, pixel_x_in_tile, pixel_y_in_tile, chr_index, plane0, plane1, color_index, palette_index, color });
        }
        // try stdout.print("x={} y={} tile_id=0x{X:0>2} plane0=0x{X:0>2} plane1=0x{X:0>2} bit0={} bit1={} color_index={} palette_index={} color=0x{X:0>6}\n", .{ x, y, tile_id, plane0, plane1, bit0, bit1, color_index, palette_index, color });
        // try stdout.print("tile=({}, {}) palette_number={} color_index={} palette_index={} color=0x{X:0>6}\n", .{ tile_x, tile_y, palette_number, color_index, palette_index, color });

        fb.setPixel(x_u8, y_u8, color);
        // for (0..30) |row| {
        //     for (0..32) |col| {
        //         const i = row * 32 + col;
        //         const tid = self.vram[0x2000 + i];
        //         try stdout.print("{X:0>2} ", .{tid});
        //     }
        //     try stdout.print("\n", .{});
        // }
    }

    pub fn writeRegister(self: *PPU, reg: u3, value: u8) void {
        // writeRegister の中
        if (reg == 6) {
            std.debug.print("writeAddr: value=0x{X:0>2}, w={}\n", .{ value, self.registers.scroll_unit.w });
            std.debug.print("LoopyRegister v = 0x{X:0>4}\n", .{self.registers.scroll_unit.v.read()});
        }

        switch (reg) {
            0 => self.writeCtrl(value),
            1 => self.writeMask(value),
            2 => {}, // read-only
            3 => self.writeOamAddr(value),
            4 => self.writeOamData(value),
            // 5 => self.registers.scroll_unit.writeScroll(value),
            // 6 => self.registers.scroll_unit.writeAddr(value),
            // 7 => self.writeData(value),
            5 => {
                std.debug.print("  Scroll write: value=0x{X:0>2} w={}\n", .{ value, self.registers.scroll_unit.w });
                self.registers.scroll_unit.writeScroll(value);
            },
            6 => {
                std.debug.print("  Addr write: value=0x{X:0>2} w={} before: t=0x{X:0>4} v=0x{X:0>4}\n", .{ value, self.registers.scroll_unit.w, self.registers.scroll_unit.t.read(), self.registers.scroll_unit.v.read() });
                self.registers.scroll_unit.writeAddr(value);
                std.debug.print("  Addr write: after: t=0x{X:0>4} v=0x{X:0>4} w={}\n", .{ self.registers.scroll_unit.t.read(), self.registers.scroll_unit.v.read(), self.registers.scroll_unit.w });
            },
            7 => {
                const addr = self.registers.scroll_unit.v.read() & 0x3FFF;
                std.debug.print("  Data write: value=0x{X:0>2} to addr=0x{X:0>4}\n", .{ value, addr });
                self.writeData(value);
            },
        }
    }

    pub fn readRegister(self: *PPU, reg: u3) u8 {
        return switch (reg) {
            2 => {
                if (!self._vblank_injected) {
                    self._vblank_injected = true;
                    self.registers.status.vblank = true; // Reset vblank after reading
                }
                return self.readStatus();
            },
            4 => self.readOamData(),
            7 => self.readData(),
            else => 0,
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

    fn writeOamData(self: *PPU, value: u8) void {
        self.registers.oam_data[self.registers.oam_addr] = value;
        self.registers.oam_addr +%= 1;
    }

    fn writeScroll(self: *PPU, value: u8) void {
        self.registers.scroll.write(value);
    }

    // fn writeData(self: *PPU, value: u8) void {
    //     const addr = self.registers.scroll_unit.v.read() & 0x3FFF;
    //     if (addr >= 0x2000 and addr <= 0x2FFF) {
    //         self.vram[addr] = value;
    //     } else {
    //         std.debug.print("💥 Warning: write to invalid PPU addr = 0x{X:0>4}\n", .{addr});
    //     }

    //     if ((self.registers.ctrl >> 2) & 0b1 == 1) {
    //         self.registers.scroll_unit.incrementVertical();
    //     } else {
    //         self.registers.scroll_unit.incrementHorizontal();
    //     }
    // }

    // fn writeData(self: *PPU, value: u8) void {
    //     var addr = self.registers.scroll_unit.v.read() & 0x3FFF;

    //     // ミラー処理: 0x3000–0x3EFF → 0x2000–0x2EFF に変換
    //     if (addr >= 0x3000 and addr < 0x3F00) {
    //         addr -= 0x1000;
    //     }

    //     if (addr >= 0x2000 and addr < 0x3000) {
    //         self.vram[addr] = value;
    //     } else {
    //         std.debug.print("💥 Warning: write to invalid PPU addr = 0x{X:0>4}\n", .{addr});
    //     }

    //     if ((self.registers.ctrl >> 2) & 0b1 == 1) {
    //         self.registers.scroll_unit.incrementVertical();
    //     } else {
    //         self.registers.scroll_unit.incrementHorizontal();
    //     }
    // }

    fn writeData(self: *PPU, value: u8) void {
        const addr = self.registers.scroll_unit.v.read() & 0x3FFF;

        std.debug.print("  writeData: raw_addr=0x{X:0>4} ", .{addr});

        // NES PPU メモリマップ処理
        if (addr >= 0x2000 and addr < 0x3000) {
            // Name tables: 0x2000-0x2FFF
            // 各Name Tableは0x400バイト（1KB）
            // ミラーリングを考慮してアドレスを正規化

            // 0x2000-0x23FF: Name Table 0
            // 0x2400-0x27FF: Name Table 1
            // 0x2800-0x2BFF: Name Table 2
            // 0x2C00-0x2FFF: Name Table 3

            // カートリッジのミラーリングタイプに応じて処理
            // 今回は垂直ミラーリング（Name Table 0,1 が同じメモリを共有）を仮定
            var mirrored_addr = addr;

            if (addr >= 0x2800) {
                // Name Table 2,3 -> Name Table 0,1 にミラー
                mirrored_addr = addr - 0x800;
            }

            std.debug.print("mirrored_addr=0x{X:0>4} ", .{mirrored_addr});

            if (mirrored_addr >= 0x2000 and mirrored_addr < 0x2800) {
                self.vram[mirrored_addr] = value;
                std.debug.print("✓ written to VRAM[0x{X:0>4}]=0x{X:0>2}", .{ mirrored_addr, value });
            } else {
                std.debug.print("✗ invalid mirrored address", .{});
            }
        } else if (addr >= 0x3000 and addr < 0x3F00) {
            // 0x3000-0x3EFF は 0x2000-0x2EFF のミラー
            var mirrored_addr = addr - 0x1000;

            // 再帰的にミラーリング処理
            if (mirrored_addr >= 0x2800) {
                mirrored_addr = mirrored_addr - 0x800;
            }

            std.debug.print("mirror_to_2xxx: mirrored_addr=0x{X:0>4} ", .{mirrored_addr});

            if (mirrored_addr >= 0x2000 and mirrored_addr < 0x2800) {
                self.vram[mirrored_addr] = value;
                std.debug.print("✓ written to VRAM[0x{X:0>4}]=0x{X:0>2}", .{ mirrored_addr, value });
            } else {
                std.debug.print("✗ invalid mirrored address", .{});
            }
        } else if (addr >= 0x3F00 and addr < 0x4000) {
            // パレットメモリ: 0x3F00-0x3FFF
            var palette_addr = addr & 0x1F; // 32バイトでリピート

            // パレットの特殊ミラーリング
            if (palette_addr == 0x10) palette_addr = 0x00;
            if (palette_addr == 0x14) palette_addr = 0x04;
            if (palette_addr == 0x18) palette_addr = 0x08;
            if (palette_addr == 0x1C) palette_addr = 0x0C;

            self.palette_table[palette_addr] = value;
            std.debug.print("✓ written to palette[0x{X:0>2}]=0x{X:0>2}", .{ palette_addr, value });
        } else {
            std.debug.print("✗ invalid PPU address", .{});
        }

        std.debug.print("\n", .{});

        // アドレスインクリメント（PPUCTRL bit 2 で方向決定）
        if ((self.registers.ctrl >> 2) & 0b1 == 1) {
            // 垂直インクリメント（+32）
            const new_addr = (self.registers.scroll_unit.v.read() + 32) & 0x7FFF;
            self.registers.scroll_unit.v.write(new_addr);
        } else {
            // 水平インクリメント（+1）
            const new_addr = (self.registers.scroll_unit.v.read() + 1) & 0x7FFF;
            self.registers.scroll_unit.v.write(new_addr);
        }
    }

    fn readStatus(self: *PPU) u8 {
        const value = self.registers.status.read();
        self.registers.scroll_unit.resetLatch();
        return value;
    }

    fn readOamData(self: *PPU) u8 {
        return self.registers.oam_data[self.registers.oam_addr];
    }

    fn readData(self: *PPU) u8 {
        const addr = self.registers.scroll_unit.v.read() & 0x3FFF;
        var result: u8 = 0;

        if (addr < 0x3F00) {
            result = self.registers.vram_buffer;
            self.registers.vram_buffer = self.vram[addr];
        } else if (addr < 0x4000) {
            const palette_index = switch (addr & 0x1F) {
                0x10 => 0x00,
                0x14 => 0x04,
                0x18 => 0x08,
                0x1C => 0x0C,
                else => addr & 0x1F,
            };
            result = self.palette_table[palette_index];

            // Open bus behavior: buffer is NOT updated with palette reads
            // Instead, buffer should hold a mirrored nametable read
            // Let's pretend we're loading from $2xxx to preserve correct state
            const mirrored = addr - 0x1000;
            self.registers.vram_buffer = self.vram[mirrored];
        }

        if ((self.registers.ctrl >> 2) & 0b1 == 1) {
            self.registers.scroll_unit.incrementVertical();
        } else {
            self.registers.scroll_unit.incrementHorizontal();
        }

        return result;
    }
};
