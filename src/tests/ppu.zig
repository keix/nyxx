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

    try std.testing.expectEqual(@as(u8, 0xAB), ppu.registers.oam.data[0x10]);
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
