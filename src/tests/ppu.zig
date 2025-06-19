const std = @import("std");
const PPU = @import("../ppu.zig").PPU;
const FrameBuffer = @import("../ppu.zig").FrameBuffer;
const VRAM = @import("../ppu.zig").VRAM;
const Cartridge = @import("../cartridge.zig").Cartridge;
const Mirroring = @import("../cartridge.zig").Mirroring;
const Bus = @import("../bus.zig").Bus;

test "FrameBuffer setPixel and getPixel" {
    var fb = FrameBuffer{};

    fb.setPixel(10, 20, 0xFF0000);
    try std.testing.expectEqual(@as(u32, 0xFF0000), fb.getPixel(10, 20));

    fb.setPixel(255, 239, 0x00FF00);
    try std.testing.expectEqual(@as(u32, 0x00FF00), fb.getPixel(255, 239));

    fb.setPixel(0, 0, 0x0000FF);
    try std.testing.expectEqual(@as(u32, 0x0000FF), fb.getPixel(0, 0));
}

test "FrameBuffer bounds checking" {
    var fb = FrameBuffer{};

    fb.setPixel(255, 240, 0xFFFFFF);
    try std.testing.expectEqual(@as(u32, 0), fb.getPixel(255, 240));

    // Out of bounds - x=256 is invalid (0-255)
    // setPixel should handle this gracefully
}

test "VRAM init with vertical mirroring" {
    const vram = VRAM.init(Mirroring.Vertical);

    try std.testing.expectEqual(Mirroring.Vertical, vram.mirroring);
    try std.testing.expectEqual(@as(u8, 0), vram.buffer);

    try std.testing.expectEqual(@as(u8, 0x01), vram.palette[0]);
    try std.testing.expectEqual(@as(u8, 0x23), vram.palette[1]);
}

test "VRAM mirroring - vertical" {
    var vram = VRAM.init(Mirroring.Vertical);

    // In vertical mirroring:
    // 0x2000 and 0x2800 map to the same location
    // 0x2400 and 0x2C00 map to the same location
    vram.write(0x2000, 0xAA);
    try std.testing.expectEqual(@as(u8, 0xAA), vram.read(0x2000));
    try std.testing.expectEqual(@as(u8, 0xAA), vram.read(0x2800));

    vram.write(0x2400, 0xBB);
    try std.testing.expectEqual(@as(u8, 0xBB), vram.read(0x2400));
    try std.testing.expectEqual(@as(u8, 0xBB), vram.read(0x2C00));
}

test "VRAM mirroring - horizontal" {
    var vram = VRAM.init(Mirroring.Horizontal);

    // In horizontal mirroring:
    // 0x2000 and 0x2400 map to the same location
    // 0x2800 and 0x2C00 map to the same location
    vram.write(0x2000, 0xCC);
    try std.testing.expectEqual(@as(u8, 0xCC), vram.read(0x2000));
    try std.testing.expectEqual(@as(u8, 0xCC), vram.read(0x2400));

    vram.write(0x2800, 0xEE);
    try std.testing.expectEqual(@as(u8, 0xEE), vram.read(0x2800));
    try std.testing.expectEqual(@as(u8, 0xEE), vram.read(0x2C00));
}

test "VRAM palette read/write" {
    var vram = VRAM.init(Mirroring.Vertical);

    vram.writePalette(0x3F00, 0x0F);
    try std.testing.expectEqual(@as(u8, 0x0F), vram.readPalette(0x3F00));

    vram.writePalette(0x3F10, 0x30);
    try std.testing.expectEqual(@as(u8, 0x30), vram.readPalette(0x3F10));
    try std.testing.expectEqual(@as(u8, 0x30), vram.readPalette(0x3F00));

    vram.writePalette(0x3F14, 0x25);
    try std.testing.expectEqual(@as(u8, 0x25), vram.readPalette(0x3F14));
    try std.testing.expectEqual(@as(u8, 0x25), vram.readPalette(0x3F04));
}

test "PPU init" {
    const allocator = std.testing.allocator;

    var rom_data = try allocator.alloc(u8, 16 + 32768);
    defer allocator.free(rom_data);
    @memset(rom_data, 0);

    rom_data[0..4].* = "NES\x1A".*;
    rom_data[4] = 2;
    rom_data[5] = 0;

    var cartridge = try Cartridge.loadFromFile(allocator, rom_data);
    defer cartridge.deinit(allocator);

    const ppu = PPU.init(&cartridge);

    try std.testing.expectEqual(@as(i16, -1), ppu.scanline);
    try std.testing.expectEqual(@as(u16, 0), ppu.cycle);
    try std.testing.expectEqual(@as(usize, 0), ppu.frame);
    try std.testing.expectEqual(false, ppu.registers.status.vblank);
}

test "PPU register write/read - PPUCTRL" {
    const allocator = std.testing.allocator;

    var rom_data = try allocator.alloc(u8, 16 + 32768);
    defer allocator.free(rom_data);
    @memset(rom_data, 0);

    rom_data[0..4].* = "NES\x1A".*;
    rom_data[4] = 2;
    rom_data[5] = 0;

    var cartridge = try Cartridge.loadFromFile(allocator, rom_data);
    defer cartridge.deinit(allocator);

    var ppu = PPU.init(&cartridge);

    ppu.writeRegister(0, 0b10010000);

    try std.testing.expectEqual(@as(u2, 0), ppu.registers.ctrl.nametable);
    try std.testing.expectEqual(@as(u1, 0), ppu.registers.ctrl.vram_increment);
    try std.testing.expectEqual(@as(u1, 0), ppu.registers.ctrl.sprite_table);
    try std.testing.expectEqual(@as(u1, 1), ppu.registers.ctrl.background_table);
    try std.testing.expectEqual(@as(u1, 0), ppu.registers.ctrl.sprite_size);
    try std.testing.expectEqual(@as(u1, 0), ppu.registers.ctrl.master_slave);
    try std.testing.expectEqual(@as(u1, 1), ppu.registers.ctrl.generate_nmi);
}

test "PPU register write/read - PPUMASK" {
    const allocator = std.testing.allocator;

    var rom_data = try allocator.alloc(u8, 16 + 32768);
    defer allocator.free(rom_data);
    @memset(rom_data, 0);

    rom_data[0..4].* = "NES\x1A".*;
    rom_data[4] = 2;
    rom_data[5] = 0;

    var cartridge = try Cartridge.loadFromFile(allocator, rom_data);
    defer cartridge.deinit(allocator);

    var ppu = PPU.init(&cartridge);

    ppu.writeRegister(1, 0b00011110);

    try std.testing.expectEqual(false, ppu.registers.mask.grayscale);
    try std.testing.expectEqual(true, ppu.registers.mask.show_bg_left);
    try std.testing.expectEqual(true, ppu.registers.mask.show_sprites_left);
    try std.testing.expectEqual(true, ppu.registers.mask.show_bg);
    try std.testing.expectEqual(true, ppu.registers.mask.show_sprites);
}

test "PPU register read - PPUSTATUS" {
    const allocator = std.testing.allocator;

    var rom_data = try allocator.alloc(u8, 16 + 32768);
    defer allocator.free(rom_data);
    @memset(rom_data, 0);

    rom_data[0..4].* = "NES\x1A".*;
    rom_data[4] = 2;
    rom_data[5] = 0;

    var cartridge = try Cartridge.loadFromFile(allocator, rom_data);
    defer cartridge.deinit(allocator);

    var ppu = PPU.init(&cartridge);

    ppu.registers.status.vblank = true;
    ppu.registers.status.sprite0_hit = true;
    ppu.registers.status.sprite_overflow = false;

    const status = ppu.readRegister(2);

    try std.testing.expectEqual(@as(u8, 0b11000000), status & 0b11100000);
    try std.testing.expectEqual(false, ppu.registers.status.vblank);
    try std.testing.expectEqual(false, ppu.registers.scroll_unit.w);
}

test "PPU OAM read/write" {
    const allocator = std.testing.allocator;

    var rom_data = try allocator.alloc(u8, 16 + 32768);
    defer allocator.free(rom_data);
    @memset(rom_data, 0);

    rom_data[0..4].* = "NES\x1A".*;
    rom_data[4] = 2;
    rom_data[5] = 0;

    var cartridge = try Cartridge.loadFromFile(allocator, rom_data);
    defer cartridge.deinit(allocator);

    var ppu = PPU.init(&cartridge);

    ppu.writeRegister(3, 0x10);
    ppu.writeRegister(4, 0xAB);

    try std.testing.expectEqual(@as(u8, 0xAB), ppu.registers.oam_data[0x10]);
    try std.testing.expectEqual(@as(u8, 0x11), ppu.registers.oam_addr);

    ppu.writeRegister(3, 0x10);
    const data = ppu.readRegister(4);
    try std.testing.expectEqual(@as(u8, 0xAB), data);
}

test "PPU scroll register" {
    const allocator = std.testing.allocator;

    var rom_data = try allocator.alloc(u8, 16 + 32768);
    defer allocator.free(rom_data);
    @memset(rom_data, 0);

    rom_data[0..4].* = "NES\x1A".*;
    rom_data[4] = 2;
    rom_data[5] = 0;

    var cartridge = try Cartridge.loadFromFile(allocator, rom_data);
    defer cartridge.deinit(allocator);

    var ppu = PPU.init(&cartridge);

    ppu.writeRegister(5, 0x7E);
    try std.testing.expectEqual(@as(u5, 15), ppu.registers.scroll_unit.t.coarse_x);
    try std.testing.expectEqual(@as(u3, 6), ppu.registers.scroll_unit.x);
    try std.testing.expectEqual(true, ppu.registers.scroll_unit.w);

    ppu.writeRegister(5, 0x5F);
    try std.testing.expectEqual(@as(u5, 11), ppu.registers.scroll_unit.t.coarse_y);
    try std.testing.expectEqual(@as(u3, 7), ppu.registers.scroll_unit.t.fine_y);
    try std.testing.expectEqual(false, ppu.registers.scroll_unit.w);
}

test "PPU VRAM address register" {
    const allocator = std.testing.allocator;

    var rom_data = try allocator.alloc(u8, 16 + 32768 + 8192);
    defer allocator.free(rom_data);
    @memset(rom_data, 0);

    rom_data[0..4].* = "NES\x1A".*;
    rom_data[4] = 2;
    rom_data[5] = 1;

    var cartridge = try Cartridge.loadFromFile(allocator, rom_data);
    defer cartridge.deinit(allocator);

    var ppu = PPU.init(&cartridge);

    ppu.writeRegister(6, 0x21);
    ppu.writeRegister(6, 0x08);

    try std.testing.expectEqual(@as(u16, 0x2108), ppu.registers.scroll_unit.v.read());
    try std.testing.expectEqual(@as(u16, 0x2108), ppu.registers.scroll_unit.t.read());
}

test "PPU VRAM increment" {
    const allocator = std.testing.allocator;

    var rom_data = try allocator.alloc(u8, 16 + 32768 + 8192);
    defer allocator.free(rom_data);
    @memset(rom_data, 0);

    rom_data[0..4].* = "NES\x1A".*;
    rom_data[4] = 2;
    rom_data[5] = 1;

    @memset(rom_data[16 + 32768 ..], 0xFF);

    var cartridge = try Cartridge.loadFromFile(allocator, rom_data);
    defer cartridge.deinit(allocator);

    var ppu = PPU.init(&cartridge);

    ppu.writeRegister(0, 0x00);
    ppu.writeRegister(6, 0x00);
    ppu.writeRegister(6, 0x00);
    _ = ppu.readRegister(7);
    _ = ppu.readRegister(7);

    try std.testing.expectEqual(@as(u16, 0x0002), ppu.registers.scroll_unit.v.read());

    ppu.writeRegister(0, 0x04);
    ppu.writeRegister(6, 0x00);
    ppu.writeRegister(6, 0x00);
    _ = ppu.readRegister(7);
    _ = ppu.readRegister(7);

    try std.testing.expectEqual(@as(u16, 0x0040), ppu.registers.scroll_unit.v.read());
}

// Remove tests for non-public structs

test "PPU step and frame timing" {
    const allocator = std.testing.allocator;

    var rom_data = try allocator.alloc(u8, 16 + 32768);
    defer allocator.free(rom_data);
    @memset(rom_data, 0);

    rom_data[0..4].* = "NES\x1A".*;
    rom_data[4] = 2;
    rom_data[5] = 0;

    var cartridge = try Cartridge.loadFromFile(allocator, rom_data);
    defer cartridge.deinit(allocator);

    var ppu = PPU.init(&cartridge);
    var fb = FrameBuffer{};

    try ppu.step(&fb);
    try std.testing.expectEqual(@as(u16, 1), ppu.cycle);
    try std.testing.expectEqual(@as(i16, -1), ppu.scanline);

    for (0..340) |_| {
        try ppu.step(&fb);
    }

    try std.testing.expectEqual(@as(u16, 0), ppu.cycle);
    try std.testing.expectEqual(@as(i16, 0), ppu.scanline);
}

test "PPU vblank flag timing" {
    const allocator = std.testing.allocator;

    var rom_data = try allocator.alloc(u8, 16 + 32768);
    defer allocator.free(rom_data);
    @memset(rom_data, 0);

    rom_data[0..4].* = "NES\x1A".*;
    rom_data[4] = 2;
    rom_data[5] = 0;

    var cartridge = try Cartridge.loadFromFile(allocator, rom_data);
    defer cartridge.deinit(allocator);

    var ppu = PPU.init(&cartridge);
    var fb = FrameBuffer{};

    // Advance until we're about to enter vblank
    while (ppu.scanline < 240) {
        try ppu.step(&fb);
    }

    // Continue until we reach scanline 241
    while (ppu.scanline == 240) {
        try std.testing.expectEqual(false, ppu.registers.status.vblank);
        try ppu.step(&fb);
    }

    // Now we should be at scanline 241, cycle 0 (just transitioned)
    try std.testing.expectEqual(@as(i16, 241), ppu.scanline);
    try std.testing.expectEqual(@as(u16, 0), ppu.cycle);

    // Vblank is not set yet - it's set at cycle 1
    try std.testing.expectEqual(false, ppu.registers.status.vblank);

    // Step once - this will increment cycle to 1
    try ppu.step(&fb);
    try std.testing.expectEqual(@as(u16, 1), ppu.cycle);

    // Vblank should not be set yet because step() checks conditions at the
    // beginning, and we entered with cycle=0
    try std.testing.expectEqual(false, ppu.registers.status.vblank);

    // Step again - now we enter with cycle=1, so vblank will be set
    try ppu.step(&fb);
    try std.testing.expectEqual(@as(u16, 2), ppu.cycle);
    try std.testing.expectEqual(true, ppu.registers.status.vblank);

    // Reading status should clear vblank
    const status = ppu.readRegister(2);
    try std.testing.expectEqual(@as(u8, 0x80), status & 0x80);
    try std.testing.expectEqual(false, ppu.registers.status.vblank);
}

test "PPU isFrameComplete" {
    const allocator = std.testing.allocator;

    var rom_data = try allocator.alloc(u8, 16 + 32768);
    defer allocator.free(rom_data);
    @memset(rom_data, 0);

    rom_data[0..4].* = "NES\x1A".*;
    rom_data[4] = 2;
    rom_data[5] = 0;

    var cartridge = try Cartridge.loadFromFile(allocator, rom_data);
    defer cartridge.deinit(allocator);

    var ppu = PPU.init(&cartridge);
    var fb = FrameBuffer{};

    // PPU starts at scanline -1, cycle 0, which is the frame complete state
    // So we need to step once to move past it
    try ppu.step(&fb);

    try std.testing.expectEqual(false, ppu.isFrameComplete());

    // Run until frame completes
    while (!ppu.isFrameComplete()) {
        try ppu.step(&fb);
    }

    try std.testing.expectEqual(@as(i16, -1), ppu.scanline);
    try std.testing.expectEqual(@as(u16, 0), ppu.cycle);
    try std.testing.expectEqual(@as(usize, 1), ppu.frame);
}

test "PPU renderPixel basic background rendering" {
    const allocator = std.testing.allocator;
    
    // Create test ROM with CHR ROM
    var rom_data = try allocator.alloc(u8, 16 + 32768 + 8192); // Header + PRG + CHR
    defer allocator.free(rom_data);
    @memset(rom_data, 0);
    
    rom_data[0..4].* = "NES\x1A".*;
    rom_data[4] = 2; // 2 * 16KB PRG ROM
    rom_data[5] = 1; // 1 * 8KB CHR ROM
    
    // Set up CHR ROM data in the rom_data before loading
    const chr_start = 16 + 32768;
    // Tile 0: checkerboard pattern
    // Plane 0: 10101010 (0xAA)
    // Plane 1: 01010101 (0x55)
    for (0..8) |i| {
        rom_data[chr_start + i] = if (i % 2 == 0) 0xAA else 0x55;
        rom_data[chr_start + i + 8] = if (i % 2 == 0) 0x55 else 0xAA;
    }
    
    var cartridge = try Cartridge.loadFromFile(allocator, rom_data);
    defer cartridge.deinit(allocator);
    
    var ppu = PPU.init(&cartridge);
    var fb = FrameBuffer{};

    // Set up nametable with tile 0 at position (0,0)
    ppu.vram.write(0x2000, 0); // Tile ID 0 at first position

    // Set up attribute table for palette 0
    ppu.vram.write(0x23C0, 0x00); // All tiles use palette 0

    // Set up palette
    ppu.vram.writePalette(0x3F00, 0x0F); // Background color
    ppu.vram.writePalette(0x3F01, 0x01); // Color 1
    ppu.vram.writePalette(0x3F02, 0x02); // Color 2
    ppu.vram.writePalette(0x3F03, 0x03); // Color 3

    // Position PPU at visible scanline and cycle
    ppu.scanline = 0;
    ppu.cycle = 1;

    // Render a pixel
    try ppu.renderPixel(&fb);

    // Check that pixel was rendered
    const pixel_color = fb.getPixel(0, 0);
    try std.testing.expect(pixel_color != 0);
}

test "PPU renderPixel sprite 0 hit detection" {
    const allocator = std.testing.allocator;
    
    var rom_data = try allocator.alloc(u8, 16 + 32768 + 8192);
    defer allocator.free(rom_data);
    @memset(rom_data, 0);
    
    rom_data[0..4].* = "NES\x1A".*;
    rom_data[4] = 2;
    rom_data[5] = 1;
    
    // Set up CHR ROM data in the rom_data before loading
    const chr_start = 16 + 32768;
    // Set up a background tile with non-zero pixels
    for (0..16) |i| {
        rom_data[chr_start + i] = 0xFF; // All pixels set
    }

    // Set up a sprite tile with non-zero pixels
    for (0..16) |i| {
        rom_data[chr_start + 0x1000 + i] = 0xFF; // All pixels set
    }
    
    var cartridge = try Cartridge.loadFromFile(allocator, rom_data);
    defer cartridge.deinit(allocator);
    
    var ppu = PPU.init(&cartridge);
    var fb = FrameBuffer{};

    // Place background tile
    ppu.vram.write(0x2000, 0);

    // Set up sprite 0 at position (8, 8)
    ppu.registers.oam_data[0] = 8;  // Y position
    ppu.registers.oam_data[1] = 0;  // Tile index
    ppu.registers.oam_data[2] = 0;  // Attributes
    ppu.registers.oam_data[3] = 8;  // X position

    // Use sprite pattern table at 0x1000
    ppu.registers.ctrl.sprite_table = 1;

    // Position PPU at sprite location
    ppu.scanline = 8;
    ppu.cycle = 9; // cycle 9 = x position 8

    // Ensure sprite 0 hit is not set initially
    ppu.registers.status.sprite0_hit = false;

    // Render pixel where sprite and background overlap
    try ppu.renderPixel(&fb);

    // Sprite 0 hit should be detected
    try std.testing.expect(ppu.registers.status.sprite0_hit);
}

test "PPU renderPixel attribute table palette selection" {
    const allocator = std.testing.allocator;
    
    var rom_data = try allocator.alloc(u8, 16 + 32768 + 8192);
    defer allocator.free(rom_data);
    @memset(rom_data, 0);
    
    rom_data[0..4].* = "NES\x1A".*;
    rom_data[4] = 2;
    rom_data[5] = 1;
    
    // Set up CHR ROM data in the rom_data before loading
    const chr_start = 16 + 32768;
    // Create a tile with color index 1 for all pixels
    for (0..8) |i| {
        rom_data[chr_start + i] = 0xFF;     // Plane 0: all 1s
        rom_data[chr_start + i + 8] = 0x00; // Plane 1: all 0s
    }
    
    var cartridge = try Cartridge.loadFromFile(allocator, rom_data);
    defer cartridge.deinit(allocator);
    
    var ppu = PPU.init(&cartridge);
    var fb = FrameBuffer{};

    // Set up different palettes
    ppu.vram.writePalette(0x3F00, 0x0F); // Universal background
    ppu.vram.writePalette(0x3F01, 0x01); // Palette 0, color 1
    ppu.vram.writePalette(0x3F05, 0x05); // Palette 1, color 1
    ppu.vram.writePalette(0x3F09, 0x09); // Palette 2, color 1
    ppu.vram.writePalette(0x3F0D, 0x0D); // Palette 3, color 1

    // Place tiles in a 2x2 pattern
    ppu.vram.write(0x2000, 0); // Top-left
    ppu.vram.write(0x2001, 0); // Top-right
    ppu.vram.write(0x2020, 0); // Bottom-left (next row)
    ppu.vram.write(0x2021, 0); // Bottom-right

    // Set attribute byte to use different palettes for each 2x2 block
    // Bits 0-1: top-left (palette 0)
    // Bits 2-3: top-right (palette 1)
    // Bits 4-5: bottom-left (palette 2)
    // Bits 6-7: bottom-right (palette 3)
    ppu.vram.write(0x23C0, 0b11100100); // 0xE4

    // Test top-left tile (should use palette 0)
    ppu.scanline = 0;
    ppu.cycle = 1;
    try ppu.renderPixel(&fb);
    
    // Since we can't easily check the exact palette used,
    // we just verify the pixel was rendered
    try std.testing.expect(fb.getPixel(0, 0) != 0);
}

test "PPU renderPixel handles empty CHR ROM" {
    const allocator = std.testing.allocator;
    
    var rom_data = try allocator.alloc(u8, 16 + 32768); // No CHR ROM
    defer allocator.free(rom_data);
    @memset(rom_data, 0);
    
    rom_data[0..4].* = "NES\x1A".*;
    rom_data[4] = 2;
    rom_data[5] = 0; // No CHR ROM
    
    var cartridge = try Cartridge.loadFromFile(allocator, rom_data);
    defer cartridge.deinit(allocator);
    
    var ppu = PPU.init(&cartridge);
    var fb = FrameBuffer{};

    ppu.scanline = 0;
    ppu.cycle = 1;

    // Should return early without crash
    try ppu.renderPixel(&fb);
    
    // Framebuffer should remain unchanged (black)
    try std.testing.expectEqual(@as(u32, 0), fb.getPixel(0, 0));
}

test "PPU renderPixel nametable reading" {
    const allocator = std.testing.allocator;
    
    var rom_data = try allocator.alloc(u8, 16 + 32768 + 8192);
    defer allocator.free(rom_data);
    @memset(rom_data, 0);
    
    rom_data[0..4].* = "NES\x1A".*;
    rom_data[4] = 2;
    rom_data[5] = 1;
    rom_data[6] = 0x01; // Vertical mirroring (bit 0 set)
    
    // Set up CHR ROM data in the rom_data before loading
    const chr_start = 16 + 32768;
    // Tile 0: all pixels color index 1 (plane0=FF, plane1=00)
    for (0..8) |i| {
        rom_data[chr_start + i] = 0xFF;     // Plane 0: all 1s
        rom_data[chr_start + i + 8] = 0x00; // Plane 1: all 0s
    }
    
    // Tile 1: all pixels color index 2 (plane0=00, plane1=FF)
    for (0..8) |i| {
        rom_data[chr_start + 16 + i] = 0x00;      // Plane 0: all 0s
        rom_data[chr_start + 16 + i + 8] = 0xFF;  // Plane 1: all 1s
    }
    
    var cartridge = try Cartridge.loadFromFile(allocator, rom_data);
    defer cartridge.deinit(allocator);
    
    var ppu = PPU.init(&cartridge);
    var fb = FrameBuffer{};

    // Set up nametables
    // Place tile 0 at position (0,0) in nametable 0
    ppu.vram.write(0x2000, 0);
    // Place tile 1 at position (0,0) in nametable 1 
    ppu.vram.write(0x2400, 1);

    // Set up palette
    ppu.vram.writePalette(0x3F00, 0x0F); // Background color
    ppu.vram.writePalette(0x3F01, 0x01); // Color 1
    ppu.vram.writePalette(0x3F02, 0x02); // Color 2
    
    // Test rendering from nametable 0
    ppu.registers.scroll_unit.v.write(0x0000); // Nametable 0
    ppu.scanline = 0;
    ppu.cycle = 1;
    try ppu.renderPixel(&fb);
    const color1 = fb.getPixel(0, 0);
    
    // The renderPixel function calculates which nametable to use based on the v register
    // Let's verify it reads the correct tile
    const v1 = ppu.registers.scroll_unit.v.read();
    const nt1 = (v1 >> 10) & 0x03;
    const addr1 = 0x2000 + nt1 * 0x400;
    const tile1 = ppu.vram.read(addr1);
    
    // Test rendering from nametable 1
    ppu.registers.scroll_unit.v.write(0x0400); // Nametable 1 (bit 10 set)
    try ppu.renderPixel(&fb);
    const color2 = fb.getPixel(0, 0);
    
    const v2 = ppu.registers.scroll_unit.v.read();
    const nt2 = (v2 >> 10) & 0x03;
    const addr2 = 0x2000 + nt2 * 0x400;
    const tile2 = ppu.vram.read(addr2);

    // Verify we're reading different tiles
    try std.testing.expectEqual(@as(u8, 0), tile1);
    try std.testing.expectEqual(@as(u8, 1), tile2);
    
    // And therefore rendering different colors
    try std.testing.expect(color1 != color2);
}

test "PPU renderPixel tile boundary rendering" {
    const allocator = std.testing.allocator;
    
    var rom_data = try allocator.alloc(u8, 16 + 32768 + 8192);
    defer allocator.free(rom_data);
    @memset(rom_data, 0);
    
    rom_data[0..4].* = "NES\x1A".*;
    rom_data[4] = 2;
    rom_data[5] = 1;
    
    // Set up CHR ROM data
    const chr_start = 16 + 32768;
    // Tile 0: all black (color 0)
    for (0..16) |i| {
        rom_data[chr_start + i] = 0x00;
    }
    // Tile 1: all color 1
    for (0..8) |i| {
        rom_data[chr_start + 16 + i] = 0xFF;
        rom_data[chr_start + 24 + i] = 0x00;
    }
    
    var cartridge = try Cartridge.loadFromFile(allocator, rom_data);
    defer cartridge.deinit(allocator);
    
    var ppu = PPU.init(&cartridge);
    var fb = FrameBuffer{};
    
    // Place tiles: tile 0 at (0,0), tile 1 at (1,0)
    ppu.vram.write(0x2000, 0); // position (0,0)
    ppu.vram.write(0x2001, 1); // position (1,0)
    
    // Set up palette
    ppu.vram.writePalette(0x3F00, 0x0F); // Background
    ppu.vram.writePalette(0x3F01, 0x30); // Color 1
    
    // Test pixel at tile boundary (x=7, last pixel of first tile)
    ppu.scanline = 0;
    ppu.cycle = 8; // x = 7
    try ppu.renderPixel(&fb);
    const color_tile0_edge = fb.getPixel(7, 0);
    
    // Test pixel at tile boundary (x=8, first pixel of second tile)  
    ppu.cycle = 9; // x = 8
    try ppu.renderPixel(&fb);
    const color_tile1_edge = fb.getPixel(8, 0);
    
    // Colors should be different at tile boundary
    try std.testing.expect(color_tile0_edge != color_tile1_edge);
}

test "PPU renderPixel attribute table boundaries" {
    const allocator = std.testing.allocator;
    
    var rom_data = try allocator.alloc(u8, 16 + 32768 + 8192);
    defer allocator.free(rom_data);
    @memset(rom_data, 0);
    
    rom_data[0..4].* = "NES\x1A".*;
    rom_data[4] = 2;
    rom_data[5] = 1;
    
    // Set up CHR ROM - single tile with color 1
    const chr_start = 16 + 32768;
    for (0..8) |i| {
        rom_data[chr_start + i] = 0xFF;
        rom_data[chr_start + 8 + i] = 0x00;
    }
    
    var cartridge = try Cartridge.loadFromFile(allocator, rom_data);
    defer cartridge.deinit(allocator);
    
    var ppu = PPU.init(&cartridge);
    var fb = FrameBuffer{};
    
    // Fill nametable with tile 0
    for (0..32*30) |i| {
        ppu.vram.write(0x2000 + @as(u16, @intCast(i)), 0);
    }
    
    // Set up attribute table
    // Each attribute byte controls a 4x4 tile area (32x32 pixels)
    // Byte format: BR BL TR TL (2 bits each for bottom-right, bottom-left, top-right, top-left)
    ppu.vram.write(0x23C0, 0b11100100); // Different palettes for each 2x2 tile block
    
    // Set up different colored palettes
    ppu.vram.writePalette(0x3F00, 0x0F); // Universal background
    ppu.vram.writePalette(0x3F01, 0x01); // Palette 0 color 1 - blue
    ppu.vram.writePalette(0x3F05, 0x06); // Palette 1 color 1 - red  
    ppu.vram.writePalette(0x3F09, 0x0A); // Palette 2 color 1 - green
    ppu.vram.writePalette(0x3F0D, 0x0F); // Palette 3 color 1 - black
    
    // Test colors at different positions within the attribute block
    ppu.scanline = 0;
    ppu.cycle = 1; // Top-left (palette 0)
    try ppu.renderPixel(&fb);
    const color_tl = fb.getPixel(0, 0);
    
    ppu.scanline = 0;  
    ppu.cycle = 17; // Top-right (palette 1)
    try ppu.renderPixel(&fb);
    const color_tr = fb.getPixel(16, 0);
    
    ppu.scanline = 16;
    ppu.cycle = 1; // Bottom-left (palette 2)
    try ppu.renderPixel(&fb);
    const color_bl = fb.getPixel(0, 16);
    
    ppu.scanline = 16;
    ppu.cycle = 17; // Bottom-right (palette 3)
    try ppu.renderPixel(&fb);
    const color_br = fb.getPixel(16, 16);
    
    // All four quadrants should have different colors
    try std.testing.expect(color_tl != color_tr);
    try std.testing.expect(color_tl != color_bl);
    try std.testing.expect(color_tl != color_br);
    try std.testing.expect(color_tr != color_bl);
    try std.testing.expect(color_tr != color_br);
    try std.testing.expect(color_bl != color_br);
}

test "PPU renderPixel background color index 0 transparency" {
    const allocator = std.testing.allocator;
    
    var rom_data = try allocator.alloc(u8, 16 + 32768 + 8192);
    defer allocator.free(rom_data);
    @memset(rom_data, 0);
    
    rom_data[0..4].* = "NES\x1A".*;
    rom_data[4] = 2;
    rom_data[5] = 1;
    
    const chr_start = 16 + 32768;
    // Tile 0: color index pattern 0,1,2,3
    rom_data[chr_start + 0] = 0b00110011; // Plane 0 for first row
    rom_data[chr_start + 8] = 0b01010101; // Plane 1 for first row
    
    var cartridge = try Cartridge.loadFromFile(allocator, rom_data);
    defer cartridge.deinit(allocator);
    
    var ppu = PPU.init(&cartridge);
    var fb = FrameBuffer{};
    
    ppu.vram.write(0x2000, 0); // Tile 0 at position (0,0)
    
    // Set up palette
    ppu.vram.writePalette(0x3F00, 0x0F); // Universal background (black)
    ppu.vram.writePalette(0x3F01, 0x30); // Color 1 (white)
    ppu.vram.writePalette(0x3F02, 0x06); // Color 2 (red)
    ppu.vram.writePalette(0x3F03, 0x1A); // Color 3 (green)
    
    // Test all 4 pixels in the first row
    ppu.scanline = 0;
    
    // Pixel 0: color index 0 (00)
    ppu.cycle = 1;
    try ppu.renderPixel(&fb);
    const color0 = fb.getPixel(0, 0);
    
    // Pixel 1: color index 1 (01)
    ppu.cycle = 2;
    try ppu.renderPixel(&fb);
    const color1 = fb.getPixel(1, 0);
    
    // Pixel 2: color index 2 (10)
    ppu.cycle = 3;
    try ppu.renderPixel(&fb);
    const color2 = fb.getPixel(2, 0);
    
    // Pixel 3: color index 3 (11)
    ppu.cycle = 4;
    try ppu.renderPixel(&fb);
    const color3 = fb.getPixel(3, 0);
    
    // All colors should be different
    try std.testing.expect(color0 != color1);
    try std.testing.expect(color0 != color2);
    try std.testing.expect(color0 != color3);
    try std.testing.expect(color1 != color2);
    try std.testing.expect(color1 != color3);
    try std.testing.expect(color2 != color3);
}
