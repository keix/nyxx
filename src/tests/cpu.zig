const std = @import("std");
const CPU = @import("../6502.zig").CPU;
const PPU = @import("../ppu.zig").PPU;
const Bus = @import("../bus.zig").Bus;
const Cartridge = @import("../cartridge.zig").Cartridge;

/// Test-only helper to build a ROM image in memory
pub fn buildTestRom(allocator: std.mem.Allocator, program: []const u8, reset_vector: u16) !Cartridge {
    const header_size = 16;
    const prg_size = 32 * 1024;
    const chr_size = 0;
    const total_size = header_size + prg_size + chr_size;

    var rom = try allocator.alloc(u8, total_size);
    defer allocator.free(rom);
    @memset(rom, 0);

    // Header
    rom[0..4].* = "NES\x1A".*; // Magic
    rom[4] = 2; // 2 * 16KB PRG ROM = 32KB
    rom[5] = 0; // 0 * 8KB CHR ROM
    rom[6] = 0; // Flags 6
    rom[7] = 0; // Flags 7

    const prg_start = header_size;
    const load_offset = prg_start + (reset_vector - 0x8000);
    for (program, 0..) |byte, i| {
        rom[load_offset + i] = byte;
    }

    const reset_vector_offset = prg_start + 0x7FFC;
    rom[reset_vector_offset] = @truncate(reset_vector); // LSB
    rom[reset_vector_offset + 1] = @truncate(reset_vector >> 8); // MSB

    return Cartridge.loadFromFile(allocator, rom);
}

test "LDA loads immediate value into A and updates flags" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA9, 0x00 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step();

    try std.testing.expect(cpu.registers.a == 0x00);
    try std.testing.expect(cpu.registers.flags.z == true);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "TAX transfers A to X" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{0xAA}, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.a = 0x42;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.x == 0x42);
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "INX increments X and updates flags" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{0xE8}, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.x = 0x7F;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.x == 0x80);
    try std.testing.expect(cpu.registers.flags.n == true);
    try std.testing.expect(cpu.registers.flags.z == false);
}

test "DEX decrements X and sets flags" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{0xCA}, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.x = 1;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.x == 0);
    try std.testing.expect(cpu.registers.flags.z == true);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "CMP compares A with immediate value" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xC9, 0x42 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.a = 0x42;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.flags.z == true);
    try std.testing.expect(cpu.registers.flags.c == true);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "LDY loads immediate value into Y" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA0, 0x7F }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step();

    try std.testing.expect(cpu.registers.y == 0x7F);
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "TAY transfers A to Y and updates flags" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{0xA8}, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.a = 0x80;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.y == 0x80);
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == true);
}

test "INY increments Y and updates flags" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{0xC8}, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.y = 0xFF;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.y == 0x00);
    try std.testing.expect(cpu.registers.flags.z == true);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "DEY decrements Y and updates flags" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{0x88}, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.y = 0x01;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.y == 0x00);
    try std.testing.expect(cpu.registers.flags.z == true);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "BEQ branches if Z flag is set" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xF0, 0x02 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.flags.z = true;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.pc == 0x8004);
}

test "BEQ does not branch if Z flag is clear" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xF0, 0x02 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.flags.z = false;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.pc == 0x8000 + 0x02); // only offset fetch
}

test "BEQ takes branch and crosses page boundary (+2 cycles)" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xF0, 0x01 }, 0x80FD);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);
    cpu.registers.flags.z = true;

    const cycles = cpu.step();

    try std.testing.expect(cpu.registers.pc == 0x8100); // expected jump
    try std.testing.expect(cycles == 4); // 2 base + 2 extra (page crossed)
}

test "BNE branches if Z flag is clear" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xD0, 0x02 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.flags.z = false;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.pc == 0x8004);
}

test "BNE does not branch if Z flag is set" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xD0, 0x02 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.flags.z = true;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.pc == 0x8000 + 0x02);
}

test "BPL branches if N flag is clear" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0x10, 0x02 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);
    cpu.registers.flags.n = false;

    _ = cpu.step();
    try std.testing.expect(cpu.registers.pc == 0x8004);
}

test "BPL does not branch if N flag is set" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0x10, 0x02 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);
    cpu.registers.flags.n = true;

    _ = cpu.step();
    try std.testing.expect(cpu.registers.pc == 0x8002);
}

test "BPL takes branch and crosses page boundary (+2 cycles)" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0x10, 0x02 }, 0x80FD);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);
    cpu.registers.flags.n = false;

    const cycles = cpu.step();
    try std.testing.expect(cpu.registers.pc == 0x8101);
    try std.testing.expect(cycles == 4); // base 2 + page_crossed 2
}

test "BMI branches if N flag is set" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0x30, 0x02 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);
    cpu.registers.flags.n = true;

    _ = cpu.step();
    try std.testing.expect(cpu.registers.pc == 0x8004);
}

test "BCC branches if C flag is clear" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0x90, 0x02 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);
    cpu.registers.flags.c = false;

    _ = cpu.step();
    try std.testing.expect(cpu.registers.pc == 0x8004);
}

test "BCS branches if C flag is set" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xB0, 0x02 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);
    cpu.registers.flags.c = true;

    _ = cpu.step();
    try std.testing.expect(cpu.registers.pc == 0x8004);
}

test "BVC branches if V flag is clear" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0x50, 0x02 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);
    cpu.registers.flags.v = false;

    _ = cpu.step();
    try std.testing.expect(cpu.registers.pc == 0x8004);
}

test "BVS branches if V flag is set" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0x70, 0x02 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);
    cpu.registers.flags.v = true;

    _ = cpu.step();
    try std.testing.expect(cpu.registers.pc == 0x8004);
}

test "PHA pushes A onto stack" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{0x48}, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.a = 0xAB;
    cpu.registers.s = 0xFD;
    _ = cpu.step();

    try std.testing.expect(bus.read(0x01FD) == 0xAB);
    try std.testing.expect(cpu.registers.s == 0xFC);
}

test "PLA pulls from stack into A and updates flags" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{0x68}, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.s = 0xFC;
    bus.write(0x01FD, 0x80); // value with negative flag
    _ = cpu.step();

    try std.testing.expect(cpu.registers.a == 0x80);
    try std.testing.expect(cpu.registers.flags.n == true);
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.s == 0xFD);
}

test "PHP pushes processor flags onto the stack" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{0x08}, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.flags = .{ .n = true, .z = true, .c = true }; // sample flags
    cpu.registers.s = 0xFD;
    _ = cpu.step();

    const pushed = bus.read(0x01FD);
    try std.testing.expect((pushed & 0b10000000) != 0); // N
    try std.testing.expect((pushed & 0b00000010) != 0); // Z
    try std.testing.expect((pushed & 0b00000001) != 0); // C
    try std.testing.expect((pushed & 0b00110000) == 0b00110000); // B + bit 5
    try std.testing.expect(cpu.registers.s == 0xFC);
}

test "PLP pulls flags from stack" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{0x28}, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    bus.write(0x01FD, 0b11001101); // set various flags
    cpu.registers.s = 0xFC;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.flags.n == true);
    try std.testing.expect(cpu.registers.flags.v == true);
    try std.testing.expect(cpu.registers.flags.d == true);
    try std.testing.expect(cpu.registers.flags.i == true);
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.c == true);
    try std.testing.expect(cpu.registers.s == 0xFD);
}

test "SEC sets carry flag" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{0x38}, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.flags.c = false;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.flags.c == true);
}

test "CLC clears carry flag" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{0x18}, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.flags.c = true;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.flags.c == false);
}

test "SEI sets interrupt disable flag" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{0x78}, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.flags.i = false;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.flags.i == true);
}

test "CLI clears interrupt disable flag" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{0x58}, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.flags.i = true;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.flags.i == false);
}

test "STA stores A into zero page" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0x85, 0x10 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.a = 0x42;
    _ = cpu.step();

    try std.testing.expect(bus.read(0x0010) == 0x42);
}

test "STA stores A into absolute RAM address" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0x8D, 0x00, 0x10 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.a = 0x99;
    _ = cpu.step();

    try std.testing.expect(bus.read(0x1000) == 0x99);
}

test "STY stores Y into zero page" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0x84, 0x10 }, 0x8000); // STY $10
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);
    cpu.registers.y = 0x77;

    _ = cpu.step();

    try std.testing.expect(bus.read(0x0010) == 0x77);
}

test "STY stores Y into absolute address" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0x8C, 0x34, 0x12 }, 0x8000); // STY $1234
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);
    cpu.registers.y = 0x88;

    _ = cpu.step();

    try std.testing.expect(bus.read(0x1234) == 0x88);
}

test "STX stores X into zero page" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0x86, 0x20 }, 0x8000); // STX $20
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);
    cpu.registers.x = 0x55;

    _ = cpu.step();

    try std.testing.expect(bus.read(0x0020) == 0x55);
}

test "STX stores X into absolute address" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0x8E, 0x34, 0x12 }, 0x8000); // STX $1234
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);
    cpu.registers.x = 0xA5;

    _ = cpu.step();

    try std.testing.expect(bus.read(0x1234) == 0xA5);
}

test "LDX loads immediate value into X" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA2, 0x10 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step();

    try std.testing.expectEqual(@as(u8, 0x10), cpu.registers.x);
}

test "BIT sets Z flag if A & M == 0" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0x24, 0x10 }, 0x8000); // BIT $10
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.a = 0x00;
    bus.write(0x0010, 0xFF);

    _ = cpu.step();

    try std.testing.expect(cpu.registers.flags.z == true);
    try std.testing.expect(cpu.registers.flags.n == true);
    try std.testing.expect(cpu.registers.flags.v == true);
}

test "BIT clears Z flag if A & M != 0" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0x2C, 0x34, 0x12 }, 0x8000); // BIT $1234
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.a = 0x01;
    bus.write(0x1234, 0b0100_0001); // N=0, V=1, A&M=1

    _ = cpu.step();

    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == false);
    try std.testing.expect(cpu.registers.flags.v == true);
}

test "TXA transfers X to A and updates flags" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{0x8A}, 0x8000); // TXA
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.x = 0x00;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.a == 0x00);
    try std.testing.expect(cpu.registers.flags.z == true);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "TYA transfers Y to A and updates flags" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{0x98}, 0x8000); // TYA
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.y = 0xFF;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.a == 0xFF);
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == true);
}

test "TSX transfers stack pointer to X and updates flags" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{0xBA}, 0x8000); // TSX
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.s = 0x00;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.x == 0x00);
    try std.testing.expect(cpu.registers.flags.z == true);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "TXS transfers X to stack pointer" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{0x9A}, 0x8000); // TXS
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.x = 0xFE;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.s == 0xFE);
}

test "INC increments value at memory and sets Z/N flags" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xE6, 0x10 }, 0x8000); // INC $10
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);
    bus.write(0x0010, 0xFF);

    _ = cpu.step();

    try std.testing.expect(bus.read(0x0010) == 0x00);
    try std.testing.expect(cpu.registers.flags.z == true);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "DEC decrements value at memory and sets Z/N flags" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xC6, 0x10 }, 0x8000); // DEC $10
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);
    bus.write(0x0010, 0x01);

    _ = cpu.step();

    try std.testing.expect(bus.read(0x0010) == 0x00);
    try std.testing.expect(cpu.registers.flags.z == true);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "JMP absolute sets PC to target" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0x4C, 0x00, 0x90 }, 0x8000); // JMP $9000
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step();
    try std.testing.expect(cpu.registers.pc == 0x9000);
}

test "JMP indirect uses address stored in memory (6502 page bug case)" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0x6C, 0xFF, 0x00 }, 0x8000); // JMP ($00FF)
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    bus.write(0x00FF, 0x34); // LSB
    bus.write(0x0000, 0x12); // MSB (page wrap)

    _ = cpu.step();
    try std.testing.expect(cpu.registers.pc == 0x1234);
}

test "JSR pushes return address and jumps" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0x20, 0x00, 0x90 }, 0x8000); // JSR $9000
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    const initial_sp = cpu.registers.s;

    _ = cpu.step();

    try std.testing.expect(cpu.registers.pc == 0x9000);
    try std.testing.expect(cpu.registers.s == initial_sp - 2);

    const low = bus.read(0x0100 + @as(u16, cpu.registers.s + 1));
    const high = bus.read(0x0100 + @as(u16, cpu.registers.s + 2));

    const return_addr = (@as(u16, high) << 8) | low;

    try std.testing.expect(return_addr == 0x8002);
}

test "LDA Absolute,X with page crossing increases cycles" {
    const allocator = std.testing.allocator;
    const program = &.{
        0xA2, 0x01, // LDX #$01
        0xBD, 0xFF, 0x80, // LDA $80FF,X → addr = $8100 (page crossed)
    };
    var cartridge = try buildTestRom(allocator, program, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    try std.testing.expect(cpu.step() == 2); // LDX
    const cycles = cpu.step(); // LDA Absolute,X
    try std.testing.expect(cycles == 5); // +1 cycle due to page crossing
}

test "RTS pulls return address and jumps to PC+1" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{0x60}, 0x8000); // RTS opcode
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.s = 0xFD;
    bus.write(0x01FE, 0x34); // low
    bus.write(0x01FF, 0x12); // high

    const cycles = cpu.step();

    try std.testing.expect(cpu.registers.pc == 0x1235);
    try std.testing.expect(cpu.registers.s == 0xFF);
    try std.testing.expect(cycles == 6);
}

test "RTI restores flags and jumps to PC" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{0x40}, 0x8000); // RTI
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.s = 0xFC;
    bus.write(0x01FD, 0b11001101); // flags
    bus.write(0x01FE, 0x34); // PC lo
    bus.write(0x01FF, 0x12); // PC hi

    const cycles = cpu.step();

    try std.testing.expect(cpu.registers.flags.n == true);
    try std.testing.expect(cpu.registers.flags.v == true);
    try std.testing.expect(cpu.registers.flags.d == true);
    try std.testing.expect(cpu.registers.flags.i == true);
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.c == true);

    try std.testing.expect(cpu.registers.pc == 0x1234);
    try std.testing.expect(cpu.registers.s == 0xFF);
    try std.testing.expect(cycles == 6);
}

test "ADC immediate adds correctly without carry or overflow" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0x69, 0x10 }, 0x8000); // ADC #$10
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.a = 0x20;
    cpu.registers.flags.c = false;

    const cycles = cpu.step();

    try std.testing.expect(cpu.registers.a == 0x30);
    try std.testing.expect(cpu.registers.flags.c == false);
    try std.testing.expect(cpu.registers.flags.v == false);
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == false);
    try std.testing.expect(cycles == 2);
}

test "ADC zero page" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0x65, 0x10 }, 0x8000); // ADC $10
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);
    bus.write(0x0010, 0x05);

    cpu.registers.a = 0x03;
    cpu.registers.flags.c = false;

    _ = cpu.step();

    try std.testing.expect(cpu.registers.a == 0x08);
}

test "ADC zero page,X" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0x75, 0x10 }, 0x8000); // ADC $10,X
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);
    cpu.registers.x = 0x01;
    bus.write(0x0011, 0x02);

    cpu.registers.a = 0x01;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.a == 0x03);
}

test "ADC absolute" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0x6D, 0x34, 0x12 }, 0x8000); // ADC $1234
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);
    bus.write(0x1234, 0x10);

    cpu.registers.a = 0x01;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.a == 0x11);
}

test "ADC absolute,X with page crossing (in RAM)" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0x7D, 0xFF, 0x00 }, 0x8000); // ADC $00FF,X
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.x = 0x01;
    cpu.registers.a = 0x01;
    bus.write(0x0100, 0x01);

    const cycles = cpu.step();

    try std.testing.expect(cpu.registers.a == 0x02);
    try std.testing.expect(cycles == 5);
}

test "ADC absolute,Y" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0x79, 0x00, 0x02 }, 0x8000); // ADC $0200,Y
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.a = 0x03;
    cpu.registers.y = 0x01;
    bus.write(0x0201, 0x02); // 0x0200 + Y = 0x0201

    const cycles = cpu.step();
    try std.testing.expect(cpu.registers.a == 0x05);
    try std.testing.expect(cycles == 4);
}

test "ADC indirect,Y" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0x71, 0x10 }, 0x8000); // ADC ($10),Y
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    // ($10) = 0x0200, Y = 1 → target = 0x0201
    bus.write(0x0010, 0x00); // low byte
    bus.write(0x0011, 0x02); // high byte
    bus.write(0x0201, 0x02); // target address

    cpu.registers.a = 0x03;
    cpu.registers.y = 0x01;

    const cycles = cpu.step();
    try std.testing.expect(cpu.registers.a == 0x05);
    try std.testing.expect(cycles == 5);
}

test "SBC absolute" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xED, 0x03, 0x80, 0x02 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.a = 0x05;
    cpu.registers.flags.c = true;

    const cycles = cpu.step();
    try std.testing.expect(cpu.registers.a == 0x03);
    try std.testing.expect(cycles == 4);
}

test "SBC absolute,X" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xFD, 0x04, 0x80, 0x00, 0x00, 0x00, 0x02 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);
    cpu.registers.a = 0x05;
    cpu.registers.x = 0x02;
    cpu.registers.flags.c = true;

    const cycles = cpu.step();
    try std.testing.expect(cpu.registers.a == 0x03);
    try std.testing.expect(cycles == 4);
}

test "SBC zero page" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xE5, 0x10 }, 0x8000); // SBC $10
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    bus.write(0x0010, 0x02);

    cpu.registers.a = 0x05;
    cpu.registers.flags.c = true;

    const cycles = cpu.step();
    try std.testing.expect(cpu.registers.a == 0x03); // 0x05 - 0x02 = 0x03
    try std.testing.expect(cycles == 3);
}

test "SBC zero page,X" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xF5, 0x10 }, 0x8000); // SBC $10,X
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.x = 0x01;
    bus.write(0x0011, 0x01);

    cpu.registers.a = 0x05;
    cpu.registers.flags.c = true;

    const cycles = cpu.step();
    try std.testing.expect(cpu.registers.a == 0x04); // 0x05 - 0x01 = 0x04
    try std.testing.expect(cycles == 4);
}

test "SBC indirect,Y" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xF1, 0x10 }, 0x8000); // SBC ($10),Y
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    // Setup: ($10) = 0x0200, Y = 1 → effective = 0x0201
    bus.write(0x0010, 0x00); // low byte of base address
    bus.write(0x0011, 0x02); // high byte of base address
    bus.write(0x0201, 0x01); // value at effective address

    cpu.registers.a = 0x05;
    cpu.registers.y = 0x01;
    cpu.registers.flags.c = true; // no borrow

    const cycles = cpu.step();
    try std.testing.expect(cpu.registers.a == 0x04); // 0x05 - 0x01 = 0x04
    try std.testing.expect(cycles == 5);
}

test "SBC immediate" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xE9, 0x02 }, 0x8000); // SBC #$02
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.a = 0x05;
    cpu.registers.flags.c = true; // no borrow

    const cycles = cpu.step();
    try std.testing.expect(cpu.registers.a == 0x03); // 0x05 - 0x02 = 0x03
    try std.testing.expect(cycles == 2);
}

test "AND immediate updates A and flags" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA9, 0xCC, 0x29, 0x0F }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step(); // LDA #$CC
    try std.testing.expect(cpu.registers.a == 0xCC);

    _ = cpu.step(); // AND #$0F
    try std.testing.expect(cpu.registers.a == 0x0C);
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "AND zero result sets zero flag" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA9, 0x0F, 0x29, 0xF0 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step(); // LDA #$0F
    _ = cpu.step(); // AND #$F0

    try std.testing.expect(cpu.registers.a == 0x00);
    try std.testing.expect(cpu.registers.flags.z == true);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "AND result sets negative flag" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA9, 0xF0, 0x29, 0xF0 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step(); // LDA #$F0
    _ = cpu.step(); // AND #$F0

    try std.testing.expect(cpu.registers.a == 0xF0);
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == true);
}

test "AND zero page" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA9, 0xFF, 0x25, 0x10 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    bus.write(0x0010, 0x0F);

    _ = cpu.step(); // LDA #$FF
    _ = cpu.step(); // AND $10

    try std.testing.expect(cpu.registers.a == 0x0F);
}

test "AND absolute,X with page crossing" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{
        0xA2, 0x01, // LDX #$01
        0xA9, 0xFF, // LDA #$FF
        0x3D, 0xFF,
        0x00, // AND $00FF,X (→ $0100, page crossed)
    }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    bus.write(0x0100, 0x0F); // Store test value at target address

    _ = cpu.step(); // LDX #$01
    _ = cpu.step(); // LDA #$FF
    const cycles = cpu.step(); // AND $00FF,X

    try std.testing.expect(cpu.registers.a == 0x0F);
    try std.testing.expect(cycles == 5); // +1 cycle for page crossing
}

test "AND absolute,Y with page crossing" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{
        0xA0, 0x02, // LDY #$02
        0xA9, 0xAA, // LDA #$AA
        0x39, 0xFE,
        0x00, // AND $00FE,Y (→ $0100, page crossed)
    }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    bus.write(0x0100, 0x55); // Store test value

    _ = cpu.step(); // LDY #$02
    _ = cpu.step(); // LDA #$AA
    const cycles = cpu.step(); // AND $00FE,Y

    try std.testing.expect(cpu.registers.a == 0x00); // 0xAA & 0x55 = 0x00
    try std.testing.expect(cpu.registers.flags.z == true);
    try std.testing.expect(cycles == 5); // +1 cycle for page crossing
}

test "AND zero page,X" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{
        0xA2, 0x05, // LDX #$05
        0xA9, 0x3C, // LDA #$3C
        0x35, 0x10, // AND $10,X (→ $15)
    }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    bus.write(0x0015, 0x18); // Store test value at $15

    _ = cpu.step(); // LDX #$05
    _ = cpu.step(); // LDA #$3C
    _ = cpu.step(); // AND $10,X

    try std.testing.expect(cpu.registers.a == 0x18); // 0x3C & 0x18 = 0x18
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "AND indirect,X" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{
        0xA2, 0x04, // LDX #$04
        0xA9, 0xF0, // LDA #$F0
        0x21, 0x20, // AND ($20,X) → ($24)
    }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    // Setup indirect address at $24-$25
    bus.write(0x0024, 0x00); // Low byte of target address
    bus.write(0x0025, 0x02); // High byte of target address → $0200
    bus.write(0x0200, 0x33); // Value at target address

    _ = cpu.step(); // LDX #$04
    _ = cpu.step(); // LDA #$F0
    _ = cpu.step(); // AND ($20,X)

    try std.testing.expect(cpu.registers.a == 0x30); // 0xF0 & 0x33 = 0x30
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "AND indirect,Y" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{
        0xA0, 0x03, // LDY #$03
        0xA9, 0xCC, // LDA #$CC
        0x31, 0x40, // AND ($40),Y
    }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    // Setup base address at $40-$41
    bus.write(0x0040, 0x00); // Low byte → $0300
    bus.write(0x0041, 0x03); // High byte
    // Effective address: $0300 + Y($03) = $0303
    bus.write(0x0303, 0x99); // Value at effective address

    _ = cpu.step(); // LDY #$03
    _ = cpu.step(); // LDA #$CC
    _ = cpu.step(); // AND ($40),Y

    try std.testing.expect(cpu.registers.a == 0x88); // 0xCC & 0x99 = 0x88
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == true); // bit 7 set
}

test "AND all addressing modes consistency" {
    const allocator = std.testing.allocator;

    // Test that all addressing modes produce the same result for the same operands
    const test_value = 0x96; // 10010110
    const mask = 0x5A; // 01011010
    const expected = 0x12; // 00010010

    // Immediate mode
    {
        var cartridge = try buildTestRom(allocator, &.{
            0xA9, test_value, // LDA #$96
            0x29, mask, // AND #$5A
        }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);

        _ = cpu.step(); // LDA
        _ = cpu.step(); // AND
        try std.testing.expect(cpu.registers.a == expected);
    }

    // Zero page mode
    {
        var cartridge = try buildTestRom(allocator, &.{
            0xA9, test_value, // LDA #$96
            0x25, 0x50, // AND $50
        }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);
        bus.write(0x0050, mask);

        _ = cpu.step(); // LDA
        _ = cpu.step(); // AND
        try std.testing.expect(cpu.registers.a == expected);
    }

    // Absolute mode
    {
        var cartridge = try buildTestRom(allocator, &.{
            0xA9, test_value, // LDA #$96
            0x2D, 0x00,
            0x03, // AND $0300
        }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);
        bus.write(0x0300, mask);

        _ = cpu.step(); // LDA
        _ = cpu.step(); // AND
        try std.testing.expect(cpu.registers.a == expected);
    }
}

test "AND edge cases" {
    const allocator = std.testing.allocator;

    // Test AND with 0x00 (should always result in 0)
    {
        var cartridge = try buildTestRom(allocator, &.{
            0xA9, 0xFF, // LDA #$FF
            0x29, 0x00, // AND #$00
        }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);

        _ = cpu.step(); // LDA
        _ = cpu.step(); // AND
        try std.testing.expect(cpu.registers.a == 0x00);
        try std.testing.expect(cpu.registers.flags.z == true);
    }

    // Test AND with 0xFF (should preserve original value)
    {
        var cartridge = try buildTestRom(allocator, &.{
            0xA9, 0x42, // LDA #$42
            0x29, 0xFF, // AND #$FF
        }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);

        _ = cpu.step(); // LDA
        _ = cpu.step(); // AND
        try std.testing.expect(cpu.registers.a == 0x42);
        try std.testing.expect(cpu.registers.flags.z == false);
        try std.testing.expect(cpu.registers.flags.n == false);
    }

    // Test AND with same value (should preserve original)
    {
        var cartridge = try buildTestRom(allocator, &.{
            0xA9, 0x81, // LDA #$81
            0x29, 0x81, // AND #$81
        }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);

        _ = cpu.step(); // LDA
        _ = cpu.step(); // AND
        try std.testing.expect(cpu.registers.a == 0x81);
        try std.testing.expect(cpu.registers.flags.z == false);
        try std.testing.expect(cpu.registers.flags.n == true); // bit 7 set
    }
}

test "ORA immediate updates A and flags" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA9, 0x0C, 0x09, 0x03 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step(); // LDA #$0C (00001100)
    try std.testing.expect(cpu.registers.a == 0x0C);

    _ = cpu.step(); // ORA #$03 (00000011)
    try std.testing.expect(cpu.registers.a == 0x0F); // 00001111
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "ORA zero value preserves original" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA9, 0x42, 0x09, 0x00 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step(); // LDA #$42
    _ = cpu.step(); // ORA #$00

    try std.testing.expect(cpu.registers.a == 0x42);
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "ORA sets negative flag" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA9, 0x70, 0x09, 0x80 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step(); // LDA #$70 (01110000)
    _ = cpu.step(); // ORA #$80 (10000000)

    try std.testing.expect(cpu.registers.a == 0xF0); // 11110000
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == true);
}

test "ORA with zero accumulator sets zero flag only when both are zero" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA9, 0x00, 0x09, 0x00 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step(); // LDA #$00
    _ = cpu.step(); // ORA #$00

    try std.testing.expect(cpu.registers.a == 0x00);
    try std.testing.expect(cpu.registers.flags.z == true);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "ORA zero page" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA9, 0x33, 0x05, 0x10 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    bus.write(0x0010, 0xCC);

    _ = cpu.step(); // LDA #$33 (00110011)
    _ = cpu.step(); // ORA $10   (11001100)

    try std.testing.expect(cpu.registers.a == 0xFF); // 11111111
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == true);
}

test "ORA zero page,X" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{
        0xA2, 0x05, // LDX #$05
        0xA9, 0x0F, // LDA #$0F
        0x15, 0x10, // ORA $10,X (→ $15)
    }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    bus.write(0x0015, 0xF0);

    _ = cpu.step(); // LDX #$05
    _ = cpu.step(); // LDA #$0F
    _ = cpu.step(); // ORA $10,X

    try std.testing.expect(cpu.registers.a == 0xFF); // 0x0F | 0xF0 = 0xFF
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == true);
}

test "ORA absolute" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{
        0xA9, 0x55, // LDA #$55 (01010101)
        0x0D, 0x00,
        0x03, // ORA $0300
    }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    bus.write(0x0300, 0xAA); // 10101010

    _ = cpu.step(); // LDA #$55
    _ = cpu.step(); // ORA $0300

    try std.testing.expect(cpu.registers.a == 0xFF); // 01010101 | 10101010 = 11111111
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == true);
}

test "ORA absolute,X with page crossing" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{
        0xA2, 0x01, // LDX #$01
        0xA9, 0x88, // LDA #$88
        0x1D, 0xFF,
        0x00, // ORA $00FF,X (→ $0100, page crossed)
    }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    bus.write(0x0100, 0x44);

    _ = cpu.step(); // LDX #$01
    _ = cpu.step(); // LDA #$88
    const cycles = cpu.step(); // ORA $00FF,X

    try std.testing.expect(cpu.registers.a == 0xCC); // 0x88 | 0x44 = 0xCC
    try std.testing.expect(cpu.registers.flags.n == true);
    try std.testing.expect(cycles == 5); // +1 cycle for page crossing
}

test "ORA absolute,Y with page crossing" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{
        0xA0, 0x02, // LDY #$02
        0xA9, 0x11, // LDA #$11
        0x19, 0xFE,
        0x00, // ORA $00FE,Y (→ $0100, page crossed)
    }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    bus.write(0x0100, 0x22);

    _ = cpu.step(); // LDY #$02
    _ = cpu.step(); // LDA #$11
    const cycles = cpu.step(); // ORA $00FE,Y

    try std.testing.expect(cpu.registers.a == 0x33); // 0x11 | 0x22 = 0x33
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == false);
    try std.testing.expect(cycles == 5); // +1 cycle for page crossing
}

test "ORA indirect,X" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{
        0xA2, 0x04, // LDX #$04
        0xA9, 0x03, // LDA #$03
        0x01, 0x20, // ORA ($20,X) → ($24)
    }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    // Setup indirect address at $24-$25
    bus.write(0x0024, 0x00); // Low byte → $0200
    bus.write(0x0025, 0x02); // High byte
    bus.write(0x0200, 0x0C); // Value at target address

    _ = cpu.step(); // LDX #$04
    _ = cpu.step(); // LDA #$03
    _ = cpu.step(); // ORA ($20,X)

    try std.testing.expect(cpu.registers.a == 0x0F); // 0x03 | 0x0C = 0x0F
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "ORA indirect,Y" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{
        0xA0, 0x03, // LDY #$03
        0xA9, 0x40, // LDA #$40
        0x11, 0x40, // ORA ($40),Y
    }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    // Setup base address at $40-$41
    bus.write(0x0040, 0x00); // Low byte → $0300
    bus.write(0x0041, 0x03); // High byte
    // Effective address: $0300 + Y($03) = $0303
    bus.write(0x0303, 0x80); // Value at effective address

    _ = cpu.step(); // LDY #$03
    _ = cpu.step(); // LDA #$40
    _ = cpu.step(); // ORA ($40),Y

    try std.testing.expect(cpu.registers.a == 0xC0); // 0x40 | 0x80 = 0xC0
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == true); // bit 7 set
}

test "ORA edge cases" {
    const allocator = std.testing.allocator;

    // Test ORA with 0xFF (should always result in 0xFF)
    {
        var cartridge = try buildTestRom(allocator, &.{
            0xA9, 0x00, // LDA #$00
            0x09, 0xFF, // ORA #$FF
        }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);

        _ = cpu.step(); // LDA
        _ = cpu.step(); // ORA
        try std.testing.expect(cpu.registers.a == 0xFF);
        try std.testing.expect(cpu.registers.flags.z == false);
        try std.testing.expect(cpu.registers.flags.n == true);
    }

    // Test ORA with complementary values
    {
        var cartridge = try buildTestRom(allocator, &.{
            0xA9, 0xF0, // LDA #$F0 (11110000)
            0x09, 0x0F, // ORA #$0F (00001111)
        }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);

        _ = cpu.step(); // LDA
        _ = cpu.step(); // ORA
        try std.testing.expect(cpu.registers.a == 0xFF); // All bits set
        try std.testing.expect(cpu.registers.flags.z == false);
        try std.testing.expect(cpu.registers.flags.n == true);
    }
}

test "EOR immediate updates A and flags" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA9, 0xCC, 0x49, 0xAA }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step(); // LDA #$CC (11001100)
    try std.testing.expect(cpu.registers.a == 0xCC);

    _ = cpu.step(); // EOR #$AA (10101010)
    try std.testing.expect(cpu.registers.a == 0x66); // 11001100 ^ 10101010 = 01100110
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "EOR with same value results in zero" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA9, 0x42, 0x49, 0x42 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step(); // LDA #$42
    _ = cpu.step(); // EOR #$42

    try std.testing.expect(cpu.registers.a == 0x00);
    try std.testing.expect(cpu.registers.flags.z == true);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "EOR sets negative flag" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA9, 0x70, 0x49, 0xFF }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step(); // LDA #$70 (01110000)
    _ = cpu.step(); // EOR #$FF (11111111)

    try std.testing.expect(cpu.registers.a == 0x8F); // 01110000 ^ 11111111 = 10001111
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == true);
}

test "EOR with zero preserves original value" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA9, 0x55, 0x49, 0x00 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step(); // LDA #$55
    _ = cpu.step(); // EOR #$00

    try std.testing.expect(cpu.registers.a == 0x55); // 任意の値 ^ 0 = 元の値
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "EOR zero page" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA9, 0xF0, 0x45, 0x10 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    bus.write(0x0010, 0x0F);

    _ = cpu.step(); // LDA #$F0 (11110000)
    _ = cpu.step(); // EOR $10   (00001111)

    try std.testing.expect(cpu.registers.a == 0xFF); // 11110000 ^ 00001111 = 11111111
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == true);
}

test "EOR zero page,X" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{
        0xA2, 0x03, // LDX #$03
        0xA9, 0x99, // LDA #$99
        0x55, 0x20, // EOR $20,X (→ $23)
    }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    bus.write(0x0023, 0x66);

    _ = cpu.step(); // LDX #$03
    _ = cpu.step(); // LDA #$99
    _ = cpu.step(); // EOR $20,X

    try std.testing.expect(cpu.registers.a == 0xFF); // 0x99 ^ 0x66 = 0xFF
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == true);
}

test "EOR absolute" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{
        0xA9, 0x3C, // LDA #$3C (00111100)
        0x4D, 0x00,
        0x03, // EOR $0300
    }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    bus.write(0x0300, 0xC3); // 11000011

    _ = cpu.step(); // LDA #$3C
    _ = cpu.step(); // EOR $0300

    try std.testing.expect(cpu.registers.a == 0xFF); // 00111100 ^ 11000011 = 11111111
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == true);
}

test "EOR absolute,X with page crossing" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{
        0xA2, 0x01, // LDX #$01
        0xA9, 0xA5, // LDA #$A5
        0x5D, 0xFF,
        0x00, // EOR $00FF,X (→ $0100, page crossed)
    }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    bus.write(0x0100, 0x5A);

    _ = cpu.step(); // LDX #$01
    _ = cpu.step(); // LDA #$A5
    const cycles = cpu.step(); // EOR $00FF,X

    try std.testing.expect(cpu.registers.a == 0xFF); // 0xA5 ^ 0x5A = 0xFF
    try std.testing.expect(cpu.registers.flags.n == true);
    try std.testing.expect(cycles == 5); // +1 cycle for page crossing
}

test "EOR absolute,Y with page crossing" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{
        0xA0, 0x02, // LDY #$02
        0xA9, 0x18, // LDA #$18
        0x59, 0xFE,
        0x00, // EOR $00FE,Y (→ $0100, page crossed)
    }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    bus.write(0x0100, 0x18);

    _ = cpu.step(); // LDY #$02
    _ = cpu.step(); // LDA #$18
    const cycles = cpu.step(); // EOR $00FE,Y

    try std.testing.expect(cpu.registers.a == 0x00); // 0x18 ^ 0x18 = 0x00
    try std.testing.expect(cpu.registers.flags.z == true);
    try std.testing.expect(cpu.registers.flags.n == false);
    try std.testing.expect(cycles == 5); // +1 cycle for page crossing
}

test "EOR indirect,X" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{
        0xA2, 0x04, // LDX #$04
        0xA9, 0xC6, // LDA #$C6
        0x41, 0x20, // EOR ($20,X) → ($24)
    }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    // Setup indirect address at $24-$25
    bus.write(0x0024, 0x00); // Low byte → $0200
    bus.write(0x0025, 0x02); // High byte
    bus.write(0x0200, 0x39); // Value at target address

    _ = cpu.step(); // LDX #$04
    _ = cpu.step(); // LDA #$C6
    _ = cpu.step(); // EOR ($20,X)

    try std.testing.expect(cpu.registers.a == 0xFF); // 0xC6 ^ 0x39 = 0xFF
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == true);
}

test "EOR indirect,Y" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{
        0xA0, 0x05, // LDY #$05
        0xA9, 0x81, // LDA #$81
        0x51, 0x40, // EOR ($40),Y
    }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    // Setup base address at $40-$41
    bus.write(0x0040, 0x00); // Low byte → $0300
    bus.write(0x0041, 0x03); // High byte
    // Effective address: $0300 + Y($05) = $0305
    bus.write(0x0305, 0x81); // Value at effective address

    _ = cpu.step(); // LDY #$05
    _ = cpu.step(); // LDA #$81
    _ = cpu.step(); // EOR ($40),Y

    try std.testing.expect(cpu.registers.a == 0x00); // 0x81 ^ 0x81 = 0x00
    try std.testing.expect(cpu.registers.flags.z == true);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "EOR bit manipulation patterns" {
    const allocator = std.testing.allocator;

    // Test bit toggling with EOR
    {
        var cartridge = try buildTestRom(allocator, &.{
            0xA9, 0xFF, // LDA #$FF (11111111)
            0x49, 0x01, // EOR #$01 (00000001) - toggle bit 0
        }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);

        _ = cpu.step(); // LDA
        _ = cpu.step(); // EOR
        try std.testing.expect(cpu.registers.a == 0xFE); // 11111110
        try std.testing.expect(cpu.registers.flags.n == true);
    }

    // Test bit mask clearing
    {
        var cartridge = try buildTestRom(allocator, &.{
            0xA9, 0b10101010, // LDA #$AA
            0x49, 0b11110000, // EOR #$F0 - toggle upper 4 bits
        }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);

        _ = cpu.step(); // LDA
        _ = cpu.step(); // EOR
        try std.testing.expect(cpu.registers.a == 0b01011010); // 0x5A
        try std.testing.expect(cpu.registers.flags.z == false);
        try std.testing.expect(cpu.registers.flags.n == false);
    }
}

test "EOR all addressing modes consistency" {
    const allocator = std.testing.allocator;

    // Test that all addressing modes produce the same result for the same operands
    const test_value = 0xA3; // 10100011
    const xor_mask = 0x5C; // 01011100
    const expected = 0xFF; // 11111111

    // Immediate mode
    {
        var cartridge = try buildTestRom(allocator, &.{
            0xA9, test_value, // LDA #$A3
            0x49, xor_mask, // EOR #$5C
        }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);

        _ = cpu.step(); // LDA
        _ = cpu.step(); // EOR
        try std.testing.expect(cpu.registers.a == expected);
    }

    // Zero page mode
    {
        var cartridge = try buildTestRom(allocator, &.{
            0xA9, test_value, // LDA #$A3
            0x45, 0x50, // EOR $50
        }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);
        bus.write(0x0050, xor_mask);

        _ = cpu.step(); // LDA
        _ = cpu.step(); // EOR
        try std.testing.expect(cpu.registers.a == expected);
    }

    // Absolute mode
    {
        var cartridge = try buildTestRom(allocator, &.{
            0xA9, test_value, // LDA #$A3
            0x4D, 0x00,
            0x04, // EOR $0400
        }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);
        bus.write(0x0400, xor_mask);

        _ = cpu.step(); // LDA
        _ = cpu.step(); // EOR
        try std.testing.expect(cpu.registers.a == expected);
    }
}

test "EOR edge cases" {
    const allocator = std.testing.allocator;

    // Double EOR returns to original value
    {
        var cartridge = try buildTestRom(allocator, &.{
            0xA9, 0x77, // LDA #$77
            0x49, 0x23, // EOR #$23
            0x49, 0x23, // EOR #$23 again
        }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);

        _ = cpu.step(); // LDA
        _ = cpu.step(); // EOR (first)
        _ = cpu.step(); // EOR (second)
        try std.testing.expect(cpu.registers.a == 0x77); // Back to original
    }

    // EOR with all bits set (complement)
    {
        var cartridge = try buildTestRom(allocator, &.{
            0xA9, 0x0F, // LDA #$0F (00001111)
            0x49, 0xFF, // EOR #$FF (11111111)
        }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);

        _ = cpu.step(); // LDA
        _ = cpu.step(); // EOR
        try std.testing.expect(cpu.registers.a == 0xF0); // Complement: 11110000
        try std.testing.expect(cpu.registers.flags.n == true);
    }
}

test "CPX immediate - equal values" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA2, 0x42, 0xE0, 0x42 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step(); // LDX #$42
    try std.testing.expect(cpu.registers.x == 0x42);

    _ = cpu.step(); // CPX #$42
    try std.testing.expect(cpu.registers.flags.z == true); // X == value
    try std.testing.expect(cpu.registers.flags.c == true); // X >= value (no borrow)
    try std.testing.expect(cpu.registers.flags.n == false); // result positive
}

test "CPX immediate - X greater than value" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA2, 0x50, 0xE0, 0x30 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step(); // LDX #$50
    _ = cpu.step(); // CPX #$30

    try std.testing.expect(cpu.registers.flags.z == false); // X != value
    try std.testing.expect(cpu.registers.flags.c == true); // X >= value (no borrow)
    try std.testing.expect(cpu.registers.flags.n == false); // result positive (0x50 - 0x30 = 0x20)
}

test "CPX immediate - X less than value" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA2, 0x30, 0xE0, 0x50 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step(); // LDX #$30
    _ = cpu.step(); // CPX #$50

    try std.testing.expect(cpu.registers.flags.z == false); // X != value
    try std.testing.expect(cpu.registers.flags.c == false); // X < value (borrow occurred)
    try std.testing.expect(cpu.registers.flags.n == true); // result negative (0x30 - 0x50 = 0xE0)
}

test "CPX immediate - X is zero, comparing with positive" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA2, 0x00, 0xE0, 0x01 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step(); // LDX #$00
    _ = cpu.step(); // CPX #$01

    try std.testing.expect(cpu.registers.flags.z == false); // 0 != 1
    try std.testing.expect(cpu.registers.flags.c == false); // 0 < 1 (borrow)
    try std.testing.expect(cpu.registers.flags.n == true); // 0x00 - 0x01 = 0xFF (negative)
}

test "CPX immediate - comparing with zero" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA2, 0x80, 0xE0, 0x00 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step(); // LDX #$80
    _ = cpu.step(); // CPX #$00

    try std.testing.expect(cpu.registers.flags.z == false); // 0x80 != 0
    try std.testing.expect(cpu.registers.flags.c == true); // 0x80 >= 0 (no borrow)
    try std.testing.expect(cpu.registers.flags.n == true); // result has bit 7 set (0x80)
}

test "CPX zero page" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA2, 0x7F, 0xE4, 0x10 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    bus.write(0x0010, 0x7F);

    _ = cpu.step(); // LDX #$7F
    _ = cpu.step(); // CPX $10

    try std.testing.expect(cpu.registers.flags.z == true); // 0x7F == 0x7F
    try std.testing.expect(cpu.registers.flags.c == true); // 0x7F >= 0x7F
    try std.testing.expect(cpu.registers.flags.n == false); // result is 0
}

test "CPX absolute" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA2, 0x40, 0xEC, 0x00, 0x30 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    bus.write(0x3000, 0x20);

    _ = cpu.step(); // LDX #$40
    _ = cpu.step(); // CPX $3000

    try std.testing.expect(cpu.registers.flags.z == false); // 0x40 != 0x20
    try std.testing.expect(cpu.registers.flags.c == true); // 0x40 >= 0x20 (no borrow)
    try std.testing.expect(cpu.registers.flags.n == false); // 0x40 - 0x20 = 0x20 (positive)
}

test "CPX does not affect X register" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA2, 0x99, 0xE0, 0x55 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step(); // LDX #$99
    const x_before = cpu.registers.x;

    _ = cpu.step(); // CPX #$55

    try std.testing.expect(cpu.registers.x == x_before); // X register unchanged
    try std.testing.expect(cpu.registers.x == 0x99);
}

test "CPX boundary values" {
    const allocator = std.testing.allocator;

    // Test with maximum values
    {
        var cartridge = try buildTestRom(allocator, &.{ 0xA2, 0xFF, 0xE0, 0xFF }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);

        _ = cpu.step(); // LDX #$FF
        _ = cpu.step(); // CPX #$FF

        try std.testing.expect(cpu.registers.flags.z == true); // 0xFF == 0xFF
        try std.testing.expect(cpu.registers.flags.c == true); // 0xFF >= 0xFF
        try std.testing.expect(cpu.registers.flags.n == false); // result is 0
    }

    // Test 0xFF vs 0x00 (maximum difference)
    {
        var cartridge = try buildTestRom(allocator, &.{ 0xA2, 0xFF, 0xE0, 0x00 }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);

        _ = cpu.step(); // LDX #$FF
        _ = cpu.step(); // CPX #$00

        try std.testing.expect(cpu.registers.flags.z == false); // 0xFF != 0x00
        try std.testing.expect(cpu.registers.flags.c == true); // 0xFF >= 0x00
        try std.testing.expect(cpu.registers.flags.n == true); // result is 0xFF (negative)
    }

    // Test 0x00 vs 0xFF (minimum vs maximum)
    {
        var cartridge = try buildTestRom(allocator, &.{ 0xA2, 0x00, 0xE0, 0xFF }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);

        _ = cpu.step(); // LDX #$00
        _ = cpu.step(); // CPX #$FF

        try std.testing.expect(cpu.registers.flags.z == false); // 0x00 != 0xFF
        try std.testing.expect(cpu.registers.flags.c == false); // 0x00 < 0xFF (borrow)
        try std.testing.expect(cpu.registers.flags.n == false); // 0x00 - 0xFF = 0x01 (positive due to wrap)
    }
}

test "CPX cycles count" {
    const allocator = std.testing.allocator;

    // Immediate mode - 2 cycles
    {
        var cartridge = try buildTestRom(allocator, &.{ 0xA2, 0x42, 0xE0, 0x42 }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);

        _ = cpu.step(); // LDX
        const cycles = cpu.step(); // CPX immediate
        try std.testing.expect(cycles == 2);
    }

    // Zero page mode - 3 cycles
    {
        var cartridge = try buildTestRom(allocator, &.{ 0xA2, 0x42, 0xE4, 0x10 }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);
        bus.write(0x0010, 0x42);

        _ = cpu.step(); // LDX
        const cycles = cpu.step(); // CPX zero page
        try std.testing.expect(cycles == 3);
    }

    // Absolute mode - 4 cycles
    {
        var cartridge = try buildTestRom(allocator, &.{ 0xA2, 0x42, 0xEC, 0x00, 0x30 }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);
        bus.write(0x3000, 0x42);

        _ = cpu.step(); // LDX
        const cycles = cpu.step(); // CPX absolute
        try std.testing.expect(cycles == 4);
    }
}

test "CPX common usage patterns" {
    const allocator = std.testing.allocator;

    // Loop counter check (common pattern)
    {
        var cartridge = try buildTestRom(allocator, &.{
            0xA2, 0x00, // LDX #$00    ; Initialize counter
            0xE8, // INX         ; Increment counter
            0xE0, 0x05, // CPX #$05    ; Compare with limit
            0xD0, 0xFB, // BNE -5      ; Branch if not equal (loop)
        }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);

        _ = cpu.step(); // LDX #$00
        _ = cpu.step(); // INX (X = 1)
        _ = cpu.step(); // CPX #$05

        // Should not be equal yet, so Z flag should be false
        try std.testing.expect(cpu.registers.flags.z == false);
        try std.testing.expect(cpu.registers.flags.c == false); // 1 < 5

        // Continue loop several times
        for (0..4) |_| {
            _ = cpu.step(); // BNE (should branch)
            _ = cpu.step(); // INX
            _ = cpu.step(); // CPX #$05
        }

        // Now X should be 5
        try std.testing.expect(cpu.registers.x == 5);
        try std.testing.expect(cpu.registers.flags.z == true); // X == 5
        try std.testing.expect(cpu.registers.flags.c == true); // X >= 5
    }
}

test "CPY immediate - equal values" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA0, 0x42, 0xC0, 0x42 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step(); // LDY #$42
    try std.testing.expect(cpu.registers.y == 0x42);

    _ = cpu.step(); // CPY #$42
    try std.testing.expect(cpu.registers.flags.z == true); // Y == value
    try std.testing.expect(cpu.registers.flags.c == true); // Y >= value (no borrow)
    try std.testing.expect(cpu.registers.flags.n == false); // result positive
}

test "CPY immediate - Y greater than value" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA0, 0x60, 0xC0, 0x40 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step(); // LDY #$60
    _ = cpu.step(); // CPY #$40

    try std.testing.expect(cpu.registers.flags.z == false); // Y != value
    try std.testing.expect(cpu.registers.flags.c == true); // Y >= value (no borrow)
    try std.testing.expect(cpu.registers.flags.n == false); // result positive (0x60 - 0x40 = 0x20)
}

test "CPY immediate - Y less than value" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA0, 0x20, 0xC0, 0x40 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step(); // LDY #$20
    _ = cpu.step(); // CPY #$40

    try std.testing.expect(cpu.registers.flags.z == false); // Y != value
    try std.testing.expect(cpu.registers.flags.c == false); // Y < value (borrow occurred)
    try std.testing.expect(cpu.registers.flags.n == true); // result negative (0x20 - 0x40 = 0xE0)
}

test "CPY immediate - Y is zero, comparing with positive" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA0, 0x00, 0xC0, 0x01 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step(); // LDY #$00
    _ = cpu.step(); // CPY #$01

    try std.testing.expect(cpu.registers.flags.z == false); // 0 != 1
    try std.testing.expect(cpu.registers.flags.c == false); // 0 < 1 (borrow)
    try std.testing.expect(cpu.registers.flags.n == true); // 0x00 - 0x01 = 0xFF (negative)
}

test "CPY immediate - comparing with zero" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA0, 0x80, 0xC0, 0x00 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step(); // LDY #$80
    _ = cpu.step(); // CPY #$00

    try std.testing.expect(cpu.registers.flags.z == false); // 0x80 != 0
    try std.testing.expect(cpu.registers.flags.c == true); // 0x80 >= 0 (no borrow)
    try std.testing.expect(cpu.registers.flags.n == true); // result has bit 7 set (0x80)
}

test "CPY zero page" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA0, 0x7F, 0xC4, 0x10 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    bus.write(0x0010, 0x7F);

    _ = cpu.step(); // LDY #$7F
    _ = cpu.step(); // CPY $10

    try std.testing.expect(cpu.registers.flags.z == true); // 0x7F == 0x7F
    try std.testing.expect(cpu.registers.flags.c == true); // 0x7F >= 0x7F
    try std.testing.expect(cpu.registers.flags.n == false); // result is 0
}

test "CPY absolute" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA0, 0x50, 0xCC, 0x00, 0x30 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    bus.write(0x3000, 0x30);

    _ = cpu.step(); // LDY #$50
    _ = cpu.step(); // CPY $3000

    try std.testing.expect(cpu.registers.flags.z == false); // 0x50 != 0x30
    try std.testing.expect(cpu.registers.flags.c == true); // 0x50 >= 0x30 (no borrow)
    try std.testing.expect(cpu.registers.flags.n == false); // 0x50 - 0x30 = 0x20 (positive)
}

test "CPY does not affect Y register" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA0, 0x88, 0xC0, 0x44 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step(); // LDY #$88
    const y_before = cpu.registers.y;

    _ = cpu.step(); // CPY #$44

    try std.testing.expect(cpu.registers.y == y_before); // Y register unchanged
    try std.testing.expect(cpu.registers.y == 0x88);
}

test "CPY boundary values" {
    const allocator = std.testing.allocator;

    // Test with maximum values
    {
        var cartridge = try buildTestRom(allocator, &.{ 0xA0, 0xFF, 0xC0, 0xFF }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);

        _ = cpu.step(); // LDY #$FF
        _ = cpu.step(); // CPY #$FF

        try std.testing.expect(cpu.registers.flags.z == true); // 0xFF == 0xFF
        try std.testing.expect(cpu.registers.flags.c == true); // 0xFF >= 0xFF
        try std.testing.expect(cpu.registers.flags.n == false); // result is 0
    }

    // Test 0xFF vs 0x00 (maximum difference)
    {
        var cartridge = try buildTestRom(allocator, &.{ 0xA0, 0xFF, 0xC0, 0x00 }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);

        _ = cpu.step(); // LDY #$FF
        _ = cpu.step(); // CPY #$00

        try std.testing.expect(cpu.registers.flags.z == false); // 0xFF != 0x00
        try std.testing.expect(cpu.registers.flags.c == true); // 0xFF >= 0x00
        try std.testing.expect(cpu.registers.flags.n == true); // result is 0xFF (negative)
    }

    // Test 0x00 vs 0xFF (minimum vs maximum)
    {
        var cartridge = try buildTestRom(allocator, &.{ 0xA0, 0x00, 0xC0, 0xFF }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);

        _ = cpu.step(); // LDY #$00
        _ = cpu.step(); // CPY #$FF

        try std.testing.expect(cpu.registers.flags.z == false); // 0x00 != 0xFF
        try std.testing.expect(cpu.registers.flags.c == false); // 0x00 < 0xFF (borrow)
        try std.testing.expect(cpu.registers.flags.n == false); // 0x00 - 0xFF = 0x01 (positive due to wrap)
    }
}

test "CPY cycles count" {
    const allocator = std.testing.allocator;

    // Immediate mode - 2 cycles
    {
        var cartridge = try buildTestRom(allocator, &.{ 0xA0, 0x42, 0xC0, 0x42 }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);

        _ = cpu.step(); // LDY
        const cycles = cpu.step(); // CPY immediate
        try std.testing.expect(cycles == 2);
    }

    // Zero page mode - 3 cycles
    {
        var cartridge = try buildTestRom(allocator, &.{ 0xA0, 0x42, 0xC4, 0x10 }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);
        bus.write(0x0010, 0x42);

        _ = cpu.step(); // LDY
        const cycles = cpu.step(); // CPY zero page
        try std.testing.expect(cycles == 3);
    }

    // Absolute mode - 4 cycles
    {
        var cartridge = try buildTestRom(allocator, &.{ 0xA0, 0x42, 0xCC, 0x00, 0x30 }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);
        bus.write(0x3000, 0x42);

        _ = cpu.step(); // LDY
        const cycles = cpu.step(); // CPY absolute
        try std.testing.expect(cycles == 4);
    }
}

test "CPY common usage patterns" {
    const allocator = std.testing.allocator;

    // Array index check (common pattern)
    {
        var cartridge = try buildTestRom(allocator, &.{
            0xA0, 0x00, // LDY #$00    ; Initialize index
            0xC8, // INY         ; Increment index
            0xC0, 0x08, // CPY #$08    ; Compare with array size
            0xD0, 0xFB, // BNE -5      ; Branch if not equal (loop)
        }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);

        _ = cpu.step(); // LDY #$00
        _ = cpu.step(); // INY (Y = 1)
        _ = cpu.step(); // CPY #$08

        // Should not be equal yet, so Z flag should be false
        try std.testing.expect(cpu.registers.flags.z == false);
        try std.testing.expect(cpu.registers.flags.c == false); // 1 < 8

        // Continue loop several times
        for (0..7) |_| {
            _ = cpu.step(); // BNE (should branch)
            _ = cpu.step(); // INY
            _ = cpu.step(); // CPY #$08
        }

        // Now Y should be 8
        try std.testing.expect(cpu.registers.y == 8);
        try std.testing.expect(cpu.registers.flags.z == true); // Y == 8
        try std.testing.expect(cpu.registers.flags.c == true); // Y >= 8
    }

    // Countdown pattern
    {
        var cartridge = try buildTestRom(allocator, &.{
            0xA0, 0x05, // LDY #$05    ; Initialize countdown
            0x88, // DEY         ; Decrement
            0xC0, 0x00, // CPY #$00    ; Compare with zero
            0xD0, 0xFB, // BNE -5      ; Branch if not zero
        }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);

        _ = cpu.step(); // LDY #$05
        _ = cpu.step(); // DEY (Y = 4)
        _ = cpu.step(); // CPY #$00

        // Should not be zero yet
        try std.testing.expect(cpu.registers.flags.z == false);
        try std.testing.expect(cpu.registers.flags.c == true); // 4 >= 0

        // Continue countdown
        for (0..4) |_| {
            _ = cpu.step(); // BNE (should branch)
            _ = cpu.step(); // DEY
            _ = cpu.step(); // CPY #$00
        }

        // Now Y should be 0
        try std.testing.expect(cpu.registers.y == 0);
        try std.testing.expect(cpu.registers.flags.z == true); // Y == 0
        try std.testing.expect(cpu.registers.flags.c == true); // Y >= 0
    }
}

test "SED sets decimal flag" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{0xF8}, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.flags.d = false;
    _ = cpu.step(); // SED

    try std.testing.expect(cpu.registers.flags.d == true);
}

test "SED does not affect other flags" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{0xF8}, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    // Set some other flags
    cpu.registers.flags.n = true;
    cpu.registers.flags.z = true;
    cpu.registers.flags.c = true;
    cpu.registers.flags.v = true;
    cpu.registers.flags.i = true;
    cpu.registers.flags.d = false;

    _ = cpu.step(); // SED

    try std.testing.expect(cpu.registers.flags.d == true); // Changed
    try std.testing.expect(cpu.registers.flags.n == true); // Unchanged
    try std.testing.expect(cpu.registers.flags.z == true); // Unchanged
    try std.testing.expect(cpu.registers.flags.c == true); // Unchanged
    try std.testing.expect(cpu.registers.flags.v == true); // Unchanged
    try std.testing.expect(cpu.registers.flags.i == true); // Unchanged
}

test "CLD clears decimal flag" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{0xD8}, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.flags.d = true;
    _ = cpu.step(); // CLD

    try std.testing.expect(cpu.registers.flags.d == false);
}

test "CLD does not affect other flags" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{0xD8}, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    // Set all flags
    cpu.registers.flags.n = true;
    cpu.registers.flags.z = true;
    cpu.registers.flags.c = true;
    cpu.registers.flags.v = true;
    cpu.registers.flags.i = true;
    cpu.registers.flags.d = true;

    _ = cpu.step(); // CLD

    try std.testing.expect(cpu.registers.flags.d == false); // Changed
    try std.testing.expect(cpu.registers.flags.n == true); // Unchanged
    try std.testing.expect(cpu.registers.flags.z == true); // Unchanged
    try std.testing.expect(cpu.registers.flags.c == true); // Unchanged
    try std.testing.expect(cpu.registers.flags.v == true); // Unchanged
    try std.testing.expect(cpu.registers.flags.i == true); // Unchanged
}

test "CLV clears overflow flag" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{0xB8}, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.flags.v = true;
    _ = cpu.step(); // CLV

    try std.testing.expect(cpu.registers.flags.v == false);
}

test "CLV does not affect other flags" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{0xB8}, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    // Set all flags
    cpu.registers.flags.n = true;
    cpu.registers.flags.z = true;
    cpu.registers.flags.c = true;
    cpu.registers.flags.v = true;
    cpu.registers.flags.i = true;
    cpu.registers.flags.d = true;

    _ = cpu.step(); // CLV

    try std.testing.expect(cpu.registers.flags.v == false); // Changed
    try std.testing.expect(cpu.registers.flags.n == true); // Unchanged
    try std.testing.expect(cpu.registers.flags.z == true); // Unchanged
    try std.testing.expect(cpu.registers.flags.c == true); // Unchanged
    try std.testing.expect(cpu.registers.flags.i == true); // Unchanged
    try std.testing.expect(cpu.registers.flags.d == true); // Unchanged
}

test "flag instructions cycle count" {
    const allocator = std.testing.allocator;

    // SED - 2 cycles
    {
        var cartridge = try buildTestRom(allocator, &.{0xF8}, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);

        const cycles = cpu.step(); // SED
        try std.testing.expect(cycles == 2);
    }

    // CLD - 2 cycles
    {
        var cartridge = try buildTestRom(allocator, &.{0xD8}, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);

        const cycles = cpu.step(); // CLD
        try std.testing.expect(cycles == 2);
    }

    // CLV - 2 cycles
    {
        var cartridge = try buildTestRom(allocator, &.{0xB8}, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);

        const cycles = cpu.step(); // CLV
        try std.testing.expect(cycles == 2);
    }
}

test "decimal flag sequence" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{
        0xF8, // SED
        0xD8, // CLD
        0xF8, // SED
    }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    // Initially false
    try std.testing.expect(cpu.registers.flags.d == false);

    _ = cpu.step(); // SED
    try std.testing.expect(cpu.registers.flags.d == true);

    _ = cpu.step(); // CLD
    try std.testing.expect(cpu.registers.flags.d == false);

    _ = cpu.step(); // SED
    try std.testing.expect(cpu.registers.flags.d == true);
}

test "overflow flag can only be cleared, not set by CLV" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{
        0xB8, // CLV
        0xB8, // CLV (again)
    }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    // Set overflow flag manually (simulating arithmetic operation)
    cpu.registers.flags.v = true;

    _ = cpu.step(); // CLV
    try std.testing.expect(cpu.registers.flags.v == false);

    // CLV again should not change anything
    _ = cpu.step(); // CLV
    try std.testing.expect(cpu.registers.flags.v == false);
}

test "flag instructions in combination with arithmetic" {
    const allocator = std.testing.allocator;

    // Test overflow flag clearing after ADC operation
    {
        var cartridge = try buildTestRom(allocator, &.{
            0xA9, 0x7F, // LDA #$7F
            0x69, 0x01, // ADC #$01  ; Should set overflow flag (0x7F + 0x01 = 0x80)
            0xB8, // CLV       ; Clear overflow flag
        }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);

        _ = cpu.step(); // LDA #$7F
        _ = cpu.step(); // ADC #$01

        // Overflow should be set
        try std.testing.expect(cpu.registers.flags.v == true);

        _ = cpu.step(); // CLV

        // Overflow should be cleared
        try std.testing.expect(cpu.registers.flags.v == false);
        // Other flags should be unchanged
        try std.testing.expect(cpu.registers.flags.n == true); // Result was 0x80 (negative)
        try std.testing.expect(cpu.registers.flags.z == false); // Result was not zero
    }
}

test "decimal mode flag for BCD operations" {
    const allocator = std.testing.allocator;

    // Note: NES doesn't actually use decimal mode, but the flag should still work
    var cartridge = try buildTestRom(allocator, &.{
        0xF8, // SED       ; Set decimal mode
        0xA9, 0x09, // LDA #$09
        0x69, 0x01, // ADC #$01  ; In decimal mode, this would be 09 + 01 = 10 (BCD)
        0xD8, // CLD       ; Clear decimal mode
    }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step(); // SED
    try std.testing.expect(cpu.registers.flags.d == true);

    _ = cpu.step(); // LDA #$09
    _ = cpu.step(); // ADC #$01

    // In NES, decimal mode is ignored, so result should be binary: 0x09 + 0x01 = 0x0A
    try std.testing.expect(cpu.registers.a == 0x0A);

    _ = cpu.step(); // CLD
    try std.testing.expect(cpu.registers.flags.d == false);
}

test "NOP does absolutely nothing" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{0xEA}, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    // Save initial state
    const initial_a = cpu.registers.a;
    const initial_x = cpu.registers.x;
    const initial_y = cpu.registers.y;
    const initial_s = cpu.registers.s;
    const initial_flags = cpu.registers.flags;
    const initial_pc = cpu.registers.pc;

    _ = cpu.step(); // NOP

    // Everything should be exactly the same except PC
    try std.testing.expect(cpu.registers.a == initial_a);
    try std.testing.expect(cpu.registers.x == initial_x);
    try std.testing.expect(cpu.registers.y == initial_y);
    try std.testing.expect(cpu.registers.s == initial_s);

    // Check all flags individually
    try std.testing.expect(cpu.registers.flags.n == initial_flags.n);
    try std.testing.expect(cpu.registers.flags.v == initial_flags.v);
    try std.testing.expect(cpu.registers.flags.b == initial_flags.b);
    try std.testing.expect(cpu.registers.flags.d == initial_flags.d);
    try std.testing.expect(cpu.registers.flags.i == initial_flags.i);
    try std.testing.expect(cpu.registers.flags.z == initial_flags.z);
    try std.testing.expect(cpu.registers.flags.c == initial_flags.c);

    // PC should have advanced by 1 (for the NOP opcode)
    try std.testing.expect(cpu.registers.pc == initial_pc + 1);
}

test "NOP cycle count" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{0xEA}, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    const cycles = cpu.step(); // NOP
    try std.testing.expect(cycles == 2);
}

test "multiple NOPs in sequence" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{
        0xEA, // NOP
        0xEA, // NOP
        0xEA, // NOP
        0xEA, // NOP
    }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    const initial_pc = cpu.registers.pc;

    _ = cpu.step(); // NOP 1
    try std.testing.expect(cpu.registers.pc == initial_pc + 1);

    _ = cpu.step(); // NOP 2
    try std.testing.expect(cpu.registers.pc == initial_pc + 2);

    _ = cpu.step(); // NOP 3
    try std.testing.expect(cpu.registers.pc == initial_pc + 3);

    _ = cpu.step(); // NOP 4
    try std.testing.expect(cpu.registers.pc == initial_pc + 4);
}

test "NOP between meaningful operations" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{
        0xA9, 0x42, // LDA #$42
        0xEA, // NOP
        0xAA, // TAX
        0xEA, // NOP
        0xE8, // INX
    }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step(); // LDA #$42
    try std.testing.expect(cpu.registers.a == 0x42);

    _ = cpu.step(); // NOP
    try std.testing.expect(cpu.registers.a == 0x42); // Unchanged

    _ = cpu.step(); // TAX
    try std.testing.expect(cpu.registers.x == 0x42);

    _ = cpu.step(); // NOP
    try std.testing.expect(cpu.registers.x == 0x42); // Unchanged

    _ = cpu.step(); // INX
    try std.testing.expect(cpu.registers.x == 0x43);
}

test "NOP with all flags set" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{0xEA}, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    // Set all flags to true
    cpu.registers.flags.n = true;
    cpu.registers.flags.v = true;
    cpu.registers.flags.b = true;
    cpu.registers.flags.d = true;
    cpu.registers.flags.i = true;
    cpu.registers.flags.z = true;
    cpu.registers.flags.c = true;

    _ = cpu.step(); // NOP

    // All flags should remain set
    try std.testing.expect(cpu.registers.flags.n == true);
    try std.testing.expect(cpu.registers.flags.v == true);
    try std.testing.expect(cpu.registers.flags.b == true);
    try std.testing.expect(cpu.registers.flags.d == true);
    try std.testing.expect(cpu.registers.flags.i == true);
    try std.testing.expect(cpu.registers.flags.z == true);
    try std.testing.expect(cpu.registers.flags.c == true);
}

test "NOP with modified registers" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{0xEA}, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    // Set registers to specific values
    cpu.registers.a = 0xFF;
    cpu.registers.x = 0x80;
    cpu.registers.y = 0x01;
    cpu.registers.s = 0x50;

    _ = cpu.step(); // NOP

    // All registers should remain unchanged
    try std.testing.expect(cpu.registers.a == 0xFF);
    try std.testing.expect(cpu.registers.x == 0x80);
    try std.testing.expect(cpu.registers.y == 0x01);
    try std.testing.expect(cpu.registers.s == 0x50);
}

test "NOP timing in real program context" {
    const allocator = std.testing.allocator;

    // Simulate a timing-sensitive sequence where NOP might be used for delay
    var cartridge = try buildTestRom(allocator, &.{
        0xA9, 0x00, // LDA #$00    (2 cycles)
        0xEA, // NOP         (2 cycles)
        0xEA, // NOP         (2 cycles)
        0xEA, // NOP         (2 cycles)
        0x69, 0x01, // ADC #$01    (2 cycles)
    }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    var total_cycles: u32 = 0;

    total_cycles += cpu.step(); // LDA #$00
    try std.testing.expect(cpu.registers.a == 0x00);

    total_cycles += cpu.step(); // NOP 1
    total_cycles += cpu.step(); // NOP 2
    total_cycles += cpu.step(); // NOP 3

    total_cycles += cpu.step(); // ADC #$01
    try std.testing.expect(cpu.registers.a == 0x01);

    // Total should be 2 + 2 + 2 + 2 + 2 = 10 cycles
    try std.testing.expect(total_cycles == 10);
}

test "LSR accumulator - basic shift" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA9, 0x02, 0x4A }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step(); // LDA #$02
    try std.testing.expect(cpu.registers.a == 0x02);

    _ = cpu.step(); // LSR A
    try std.testing.expect(cpu.registers.a == 0x01);
    try std.testing.expect(cpu.registers.flags.c == false); // No carry out
    try std.testing.expect(cpu.registers.flags.z == false); // Result not zero
    try std.testing.expect(cpu.registers.flags.n == false); // Always positive
}

test "LSR accumulator - carry out" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA9, 0x03, 0x4A }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step(); // LDA #$03
    _ = cpu.step(); // LSR A

    try std.testing.expect(cpu.registers.a == 0x01);
    try std.testing.expect(cpu.registers.flags.c == true); // Carry out from bit 0
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "LSR accumulator - result zero" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA9, 0x01, 0x4A }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step(); // LDA #$01
    _ = cpu.step(); // LSR A

    try std.testing.expect(cpu.registers.a == 0x00);
    try std.testing.expect(cpu.registers.flags.c == true); // Carry out
    try std.testing.expect(cpu.registers.flags.z == true); // Result is zero
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "LSR accumulator - large value" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA9, 0xFE, 0x4A }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step(); // LDA #$FE (11111110)
    _ = cpu.step(); // LSR A

    try std.testing.expect(cpu.registers.a == 0x7F); // 01111111
    try std.testing.expect(cpu.registers.flags.c == false); // No carry out
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == false); // Always positive after LSR
}

test "LSR zero page" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0x46, 0x10 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    bus.write(0x0010, 0x0A); // 00001010

    _ = cpu.step(); // LSR $10

    try std.testing.expect(bus.read(0x0010) == 0x05); // 00000101
    try std.testing.expect(cpu.registers.flags.c == false); // No carry out
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "LSR zero page,X" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA2, 0x05, 0x56, 0x10 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    bus.write(0x0015, 0x07); // 00000111

    _ = cpu.step(); // LDX #$05
    _ = cpu.step(); // LSR $10,X (→ $15)

    try std.testing.expect(bus.read(0x0015) == 0x03); // 00000011
    try std.testing.expect(cpu.registers.flags.c == true); // Carry out from bit 0
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "LSR absolute" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0x4E, 0x00, 0x02 }, 0x8000); // 0x0200に変更
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    bus.write(0x0200, 0x80);

    _ = cpu.step(); // LSR $0200

    try std.testing.expect(bus.read(0x0200) == 0x40);
}

test "LSR absolute,X" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA2, 0x02, 0x5E, 0x00, 0x02 }, 0x8000); // 0x0200に変更
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    bus.write(0x0202, 0xFF); // 0x0200 + X(2) = 0x0202

    _ = cpu.step(); // LDX #$02
    _ = cpu.step(); // LSR $0200,X (→ $0202)

    try std.testing.expect(bus.read(0x0202) == 0x7F);
    try std.testing.expect(cpu.registers.flags.c == true);
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "LSR cycle counts" {
    const allocator = std.testing.allocator;

    // Accumulator mode - 2 cycles
    {
        var cartridge = try buildTestRom(allocator, &.{ 0xA9, 0x02, 0x4A }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);

        _ = cpu.step(); // LDA
        const cycles = cpu.step(); // LSR A
        try std.testing.expect(cycles == 2);
    }

    // Zero page mode - 5 cycles
    {
        var cartridge = try buildTestRom(allocator, &.{ 0x46, 0x10 }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);
        bus.write(0x0010, 0x02);

        const cycles = cpu.step(); // LSR $10
        try std.testing.expect(cycles == 5);
    }

    // Zero page,X mode - 6 cycles
    {
        var cartridge = try buildTestRom(allocator, &.{ 0xA2, 0x05, 0x56, 0x10 }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);
        bus.write(0x0015, 0x02);

        _ = cpu.step(); // LDX
        const cycles = cpu.step(); // LSR $10,X
        try std.testing.expect(cycles == 6);
    }

    // Absolute mode - 6 cycles
    {
        var cartridge = try buildTestRom(allocator, &.{ 0x4E, 0x00, 0x30 }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);
        bus.write(0x3000, 0x02);

        const cycles = cpu.step(); // LSR $3000
        try std.testing.expect(cycles == 6);
    }

    // Absolute,X mode - 7 cycles
    {
        var cartridge = try buildTestRom(allocator, &.{ 0xA2, 0x02, 0x5E, 0x00, 0x30 }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);
        bus.write(0x3002, 0x02);

        _ = cpu.step(); // LDX
        const cycles = cpu.step(); // LSR $3000,X
        try std.testing.expect(cycles == 7);
    }
}

test "LSR flag combinations" {
    const allocator = std.testing.allocator;

    // Test all possible last bit combinations
    const test_cases = [_]struct { input: u8, expected_result: u8, expected_carry: bool }{
        .{ .input = 0x00, .expected_result = 0x00, .expected_carry = false },
        .{ .input = 0x01, .expected_result = 0x00, .expected_carry = true },
        .{ .input = 0x02, .expected_result = 0x01, .expected_carry = false },
        .{ .input = 0x03, .expected_result = 0x01, .expected_carry = true },
        .{ .input = 0xFE, .expected_result = 0x7F, .expected_carry = false },
        .{ .input = 0xFF, .expected_result = 0x7F, .expected_carry = true },
    };

    for (test_cases) |case| {
        var cartridge = try buildTestRom(allocator, &.{ 0xA9, case.input, 0x4A }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);

        _ = cpu.step(); // LDA
        _ = cpu.step(); // LSR A

        try std.testing.expect(cpu.registers.a == case.expected_result);
        try std.testing.expect(cpu.registers.flags.c == case.expected_carry);
        try std.testing.expect(cpu.registers.flags.z == (case.expected_result == 0));
        try std.testing.expect(cpu.registers.flags.n == false); // LSR always clears N
    }
}

test "LSR does not affect other registers" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA9, 0x0A, 0x4A }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    // Set other registers
    cpu.registers.x = 0x11;
    cpu.registers.y = 0x22;
    cpu.registers.s = 0x33;

    _ = cpu.step(); // LDA #$0A
    _ = cpu.step(); // LSR A

    // Other registers should be unchanged
    try std.testing.expect(cpu.registers.x == 0x11);
    try std.testing.expect(cpu.registers.y == 0x22);
    try std.testing.expect(cpu.registers.s == 0x33);
}

test "LSR practical usage - divide by 2" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{
        0xA9, 0x14, // LDA #$14 (20 decimal)
        0x4A, // LSR A    (divide by 2)
        0x4A, // LSR A    (divide by 2 again)
    }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step(); // LDA #$14 (20)
    try std.testing.expect(cpu.registers.a == 20);

    _ = cpu.step(); // LSR A (20 / 2 = 10)
    try std.testing.expect(cpu.registers.a == 10);
    try std.testing.expect(cpu.registers.flags.c == false);

    _ = cpu.step(); // LSR A (10 / 2 = 5)
    try std.testing.expect(cpu.registers.a == 5);
    try std.testing.expect(cpu.registers.flags.c == false);
}

test "ASL accumulator - basic shift" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA9, 0x01, 0x0A }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step(); // LDA #$01
    try std.testing.expect(cpu.registers.a == 0x01);

    _ = cpu.step(); // ASL A
    try std.testing.expect(cpu.registers.a == 0x02);
    try std.testing.expect(cpu.registers.flags.c == false); // No carry out
    try std.testing.expect(cpu.registers.flags.z == false); // Result not zero
    try std.testing.expect(cpu.registers.flags.n == false); // Result positive
}

test "ASL accumulator - carry out" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA9, 0x80, 0x0A }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step(); // LDA #$80 (10000000)
    _ = cpu.step(); // ASL A

    try std.testing.expect(cpu.registers.a == 0x00); // 00000000
    try std.testing.expect(cpu.registers.flags.c == true); // Carry out from bit 7
    try std.testing.expect(cpu.registers.flags.z == true); // Result is zero
    try std.testing.expect(cpu.registers.flags.n == false); // Result is 0
}

test "ASL accumulator - sets negative flag" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA9, 0x40, 0x0A }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step(); // LDA #$40 (01000000)
    _ = cpu.step(); // ASL A

    try std.testing.expect(cpu.registers.a == 0x80); // 10000000
    try std.testing.expect(cpu.registers.flags.c == false); // No carry out
    try std.testing.expect(cpu.registers.flags.z == false); // Result not zero
    try std.testing.expect(cpu.registers.flags.n == true); // Negative bit set
}

test "ASL accumulator - carry and negative" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA9, 0xC0, 0x0A }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step(); // LDA #$C0 (11000000)
    _ = cpu.step(); // ASL A

    try std.testing.expect(cpu.registers.a == 0x80); // 10000000
    try std.testing.expect(cpu.registers.flags.c == true); // Carry out from bit 7
    try std.testing.expect(cpu.registers.flags.z == false); // Result not zero
    try std.testing.expect(cpu.registers.flags.n == true); // Negative bit set
}

test "ASL zero page" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0x06, 0x10 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    bus.write(0x0010, 0x05); // 00000101

    _ = cpu.step(); // ASL $10

    try std.testing.expect(bus.read(0x0010) == 0x0A); // 00001010
    try std.testing.expect(cpu.registers.flags.c == false); // No carry out
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "ASL zero page,X" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA2, 0x03, 0x16, 0x10 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    bus.write(0x0013, 0x07); // 00000111

    _ = cpu.step(); // LDX #$03
    _ = cpu.step(); // ASL $10,X (→ $13)

    try std.testing.expect(bus.read(0x0013) == 0x0E); // 00001110
    try std.testing.expect(cpu.registers.flags.c == false); // No carry out
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "ASL absolute" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0x0E, 0x00, 0x02 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    bus.write(0x0200, 0x20); // 00100000

    _ = cpu.step(); // ASL $0200

    try std.testing.expect(bus.read(0x0200) == 0x40); // 01000000
    try std.testing.expect(cpu.registers.flags.c == false); // No carry out
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "ASL absolute,X" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA2, 0x04, 0x1E, 0x00, 0x02 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    bus.write(0x0204, 0x81); // 10000001

    _ = cpu.step(); // LDX #$04
    _ = cpu.step(); // ASL $0200,X (→ $0204)

    try std.testing.expect(bus.read(0x0204) == 0x02); // 00000010
    try std.testing.expect(cpu.registers.flags.c == true); // Carry out from bit 7
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "ASL cycle counts" {
    const allocator = std.testing.allocator;

    // Accumulator mode - 2 cycles
    {
        var cartridge = try buildTestRom(allocator, &.{ 0xA9, 0x01, 0x0A }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);

        _ = cpu.step(); // LDA
        const cycles = cpu.step(); // ASL A
        try std.testing.expect(cycles == 2);
    }

    // Zero page mode - 5 cycles
    {
        var cartridge = try buildTestRom(allocator, &.{ 0x06, 0x10 }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);
        bus.write(0x0010, 0x01);

        const cycles = cpu.step(); // ASL $10
        try std.testing.expect(cycles == 5);
    }

    // Zero page,X mode - 6 cycles
    {
        var cartridge = try buildTestRom(allocator, &.{ 0xA2, 0x03, 0x16, 0x10 }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);
        bus.write(0x0013, 0x01);

        _ = cpu.step(); // LDX
        const cycles = cpu.step(); // ASL $10,X
        try std.testing.expect(cycles == 6);
    }

    // Absolute mode - 6 cycles
    {
        var cartridge = try buildTestRom(allocator, &.{ 0x0E, 0x00, 0x02 }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);
        bus.write(0x0200, 0x01);

        const cycles = cpu.step(); // ASL $0200
        try std.testing.expect(cycles == 6);
    }

    // Absolute,X mode - 7 cycles
    {
        var cartridge = try buildTestRom(allocator, &.{ 0xA2, 0x04, 0x1E, 0x00, 0x02 }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);
        bus.write(0x0204, 0x01);

        _ = cpu.step(); // LDX
        const cycles = cpu.step(); // ASL $0200,X
        try std.testing.expect(cycles == 7);
    }
}

test "ASL flag combinations" {
    const allocator = std.testing.allocator;

    // Test all possible top bit combinations
    const test_cases = [_]struct { input: u8, expected_result: u8, expected_carry: bool }{
        .{ .input = 0x00, .expected_result = 0x00, .expected_carry = false },
        .{ .input = 0x01, .expected_result = 0x02, .expected_carry = false },
        .{ .input = 0x7F, .expected_result = 0xFE, .expected_carry = false },
        .{ .input = 0x80, .expected_result = 0x00, .expected_carry = true },
        .{ .input = 0x81, .expected_result = 0x02, .expected_carry = true },
        .{ .input = 0xFF, .expected_result = 0xFE, .expected_carry = true },
    };

    for (test_cases) |case| {
        var cartridge = try buildTestRom(allocator, &.{ 0xA9, case.input, 0x0A }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);

        _ = cpu.step(); // LDA
        _ = cpu.step(); // ASL A

        try std.testing.expect(cpu.registers.a == case.expected_result);
        try std.testing.expect(cpu.registers.flags.c == case.expected_carry);
        try std.testing.expect(cpu.registers.flags.z == (case.expected_result == 0));
        try std.testing.expect(cpu.registers.flags.n == ((case.expected_result & 0x80) != 0));
    }
}

test "ASL does not affect other registers" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA9, 0x05, 0x0A }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    // Set other registers
    cpu.registers.x = 0x11;
    cpu.registers.y = 0x22;
    cpu.registers.s = 0x33;

    _ = cpu.step(); // LDA #$05
    _ = cpu.step(); // ASL A

    // Other registers should be unchanged
    try std.testing.expect(cpu.registers.x == 0x11);
    try std.testing.expect(cpu.registers.y == 0x22);
    try std.testing.expect(cpu.registers.s == 0x33);
}

test "ASL practical usage - multiply by 2" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{
        0xA9, 0x05, // LDA #$05 (5 decimal)
        0x0A, // ASL A    (multiply by 2)
        0x0A, // ASL A    (multiply by 2 again)
    }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step(); // LDA #$05 (5)
    try std.testing.expect(cpu.registers.a == 5);

    _ = cpu.step(); // ASL A (5 * 2 = 10)
    try std.testing.expect(cpu.registers.a == 10);
    try std.testing.expect(cpu.registers.flags.c == false);

    _ = cpu.step(); // ASL A (10 * 2 = 20)
    try std.testing.expect(cpu.registers.a == 20);
    try std.testing.expect(cpu.registers.flags.c == false);
}

test "ASL overflow example" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{
        0xA9, 0x90, // LDA #$90 (144 decimal)
        0x0A, // ASL A    (would overflow in signed arithmetic)
    }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    _ = cpu.step(); // LDA #$90
    _ = cpu.step(); // ASL A

    try std.testing.expect(cpu.registers.a == 0x20); // 144 * 2 = 288, truncated to 32
    try std.testing.expect(cpu.registers.flags.c == true); // Carry out indicates overflow
    try std.testing.expect(cpu.registers.flags.n == false); // Result is positive
}

test "ROL accumulator - basic rotate" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA9, 0x81, 0x2A }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.flags.c = false; // Clear carry initially

    _ = cpu.step(); // LDA #$81 (10000001)
    _ = cpu.step(); // ROL A

    try std.testing.expect(cpu.registers.a == 0x02); // 00000010 (carry was 0)
    try std.testing.expect(cpu.registers.flags.c == true); // Carry out from bit 7
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "ROL accumulator - with carry in" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA9, 0x40, 0x2A }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.flags.c = true; // Set carry initially

    _ = cpu.step(); // LDA #$40 (01000000)
    _ = cpu.step(); // ROL A

    try std.testing.expect(cpu.registers.a == 0x81); // 10000001 (carry was 1)
    try std.testing.expect(cpu.registers.flags.c == false); // No carry out
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == true); // Negative flag set
}

test "ROR accumulator - basic rotate" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA9, 0x81, 0x6A }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.flags.c = false; // Clear carry initially

    _ = cpu.step(); // LDA #$81 (10000001)
    _ = cpu.step(); // ROR A

    try std.testing.expect(cpu.registers.a == 0x40); // 01000000 (carry was 0)
    try std.testing.expect(cpu.registers.flags.c == true); // Carry out from bit 0
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "ROR accumulator - with carry in" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA9, 0x02, 0x6A }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.flags.c = true; // Set carry initially

    _ = cpu.step(); // LDA #$02 (00000010)
    _ = cpu.step(); // ROR A

    try std.testing.expect(cpu.registers.a == 0x81); // 10000001 (carry was 1)
    try std.testing.expect(cpu.registers.flags.c == false); // No carry out
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == true); // Negative flag set
}

test "ROL zero page" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0x26, 0x10 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    bus.write(0x0010, 0x55); // 01010101
    cpu.registers.flags.c = true; // Set carry

    _ = cpu.step(); // ROL $10

    try std.testing.expect(bus.read(0x0010) == 0xAB); // 10101011
    try std.testing.expect(cpu.registers.flags.c == false); // No carry out
    try std.testing.expect(cpu.registers.flags.n == true); // Negative
}

test "ROR absolute,X" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0xA2, 0x03, 0x7E, 0x00, 0x02 }, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    bus.write(0x0203, 0xAA); // 10101010
    cpu.registers.flags.c = false; // Clear carry

    _ = cpu.step(); // LDX #$03
    _ = cpu.step(); // ROR $0200,X (→ $0203)

    try std.testing.expect(bus.read(0x0203) == 0x55); // 01010101
    try std.testing.expect(cpu.registers.flags.c == false); // No carry out
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "Rotate operations comprehensive" {
    const allocator = std.testing.allocator;

    // Test 8-bit rotation with carry
    {
        var cartridge = try buildTestRom(allocator, &.{
            0xA9, 0x01, // LDA #$01
            0x2A, // ROL A (→ 0x02, C=0)
            0x2A, // ROL A (→ 0x04, C=0)
            0x2A, // ROL A (→ 0x08, C=0)
        }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);

        cpu.registers.flags.c = false;

        _ = cpu.step(); // LDA #$01
        _ = cpu.step(); // ROL A
        try std.testing.expect(cpu.registers.a == 0x02);

        _ = cpu.step(); // ROL A
        try std.testing.expect(cpu.registers.a == 0x04);

        _ = cpu.step(); // ROL A
        try std.testing.expect(cpu.registers.a == 0x08);
    }

    // Test carry propagation through rotate
    {
        var cartridge = try buildTestRom(allocator, &.{
            0xA9, 0x80, // LDA #$80
            0x2A, // ROL A (→ 0x00, C=1)
            0x2A, // ROL A (→ 0x01, C=0)
        }, 0x8000);
        defer cartridge.deinit(allocator);

        var bus = try Bus.init(&cartridge, allocator);
        defer bus.deinit();
        var cpu = CPU.init(&bus);

        cpu.registers.flags.c = false;

        _ = cpu.step(); // LDA #$80
        _ = cpu.step(); // ROL A
        try std.testing.expect(cpu.registers.a == 0x00);
        try std.testing.expect(cpu.registers.flags.c == true);

        _ = cpu.step(); // ROL A
        try std.testing.expect(cpu.registers.a == 0x01);
        try std.testing.expect(cpu.registers.flags.c == false);
    }
}

test "NOP is truly the easiest instruction to implement" {
    // This test exists to celebrate the simplicity of NOP!
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{0xEA}, 0x8000);
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    // Before NOP
    const before_state = cpu.registers;

    const cycles = cpu.step(); // NOP

    // After NOP - only PC should change
    try std.testing.expect(cpu.registers.a == before_state.a);
    try std.testing.expect(cpu.registers.x == before_state.x);
    try std.testing.expect(cpu.registers.y == before_state.y);
    try std.testing.expect(cpu.registers.s == before_state.s);
    try std.testing.expect(cpu.registers.pc == before_state.pc + 1);
    try std.testing.expect(cycles == 2);

    // NOP: The instruction that does nothing, perfectly!
}

// Helper function for testing
const DummyCart = struct {
    pub fn read(self: *const DummyCart, addr: u16) u8 {
        _ = self;
        _ = addr;
        return 0;
    }

    pub fn write(self: *DummyCart, addr: u16, value: u8) void {
        _ = self;
        _ = addr;
        _ = value;
    }
};

fn makeTestCart() DummyCart {
    return DummyCart{};
}

fn makeBus(cart: *DummyCart) !Bus {
    return Bus.init(@ptrCast(cart), std.testing.allocator);
}

// test "BRK sets correct stack and vectors" {
//     const allocator = std.testing.allocator;

//     var cartridge = try buildTestRom(allocator, &.{0x00}, 0x8000); // BRK at $8000
//     defer cartridge.deinit(allocator);

//     // Set IRQ/BRK vector
//     rom[0xFFFE] = 0x34;
//     rom[0xFFFF] = 0x12;

//     var bus = try Bus.init(&cartridge, allocator);
//     defer bus.deinit();
//     var cpu = CPU.init(&bus);

//     const initial_sp = cpu.registers.s;
//     cpu.registers.flags.z = true;

//     _ = cpu.step(); // Execute BRK

//     try std.testing.expect(cpu.registers.pc == 0x1234);
//     try std.testing.expect(cpu.registers.flags.i == true);
//     try std.testing.expect(cpu.registers.s == initial_sp - 3);

//     const stack_addr = 0x0100 + @as(u16, initial_sp) - 2;
//     const pushed_flags = bus.read(stack_addr);
//     try std.testing.expect((pushed_flags & 0b00110000) == 0b00110000);
// }

// Test for STA with PPU registers
test "STA stores A into $2000 and updates PPUCTRL" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0x8D, 0x00, 0x20 }, 0x8000); // STA $2000
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.a = 0b10100000;
    _ = cpu.step();

    try std.testing.expectEqual(@as(u8, 0b10100000), bus.ppu.registers.ctrl.read());
}

test "STA stores A into $2001 and updates PPUMASK" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0x8D, 0x01, 0x20 }, 0x8000); // STA $2001
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    cpu.registers.a = 0b00011111;
    _ = cpu.step();

    try std.testing.expectEqual(@as(u8, 0b00011111), bus.ppu.registers.mask.read());
}

test "BIT $2002 reflects PPU status VBlank and clears it" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{ 0x2C, 0x02, 0x20 }, 0x8000); // BIT $2002
    defer cartridge.deinit(allocator);

    var bus = try Bus.init(&cartridge, allocator);
    defer bus.deinit();
    var cpu = CPU.init(&bus);

    bus.ppu.registers.status.vblank = true;

    cpu.registers.a = 0xFF;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == true);
    try std.testing.expect(cpu.registers.flags.v == false);

    const status_byte = @as(u8, @bitCast(bus.ppu.registers.status));
    try std.testing.expect((status_byte & 0x80) == 0);
}

test "ScrollUnit writeScroll and writeAddr behavior" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{}, 0x8000);
    defer cartridge.deinit(allocator);

    var ppu = PPU.init(&cartridge);
    ppu.writeRegister(5, 0b0010_0101); // coarse_x = 4, x = 5
    try std.testing.expect(ppu.registers.scroll_unit.t.coarse_x == 4);
    try std.testing.expect(ppu.registers.scroll_unit.x == 5);
    try std.testing.expect(ppu.registers.scroll_unit.w == true);

    ppu.writeRegister(5, 0b1101_0110); // coarse_y = 26, fine_y = 6
    try std.testing.expect(ppu.registers.scroll_unit.t.coarse_y == 26);
    try std.testing.expect(ppu.registers.scroll_unit.t.fine_y == 6);
    try std.testing.expect(ppu.registers.scroll_unit.w == false);

    ppu.writeRegister(6, 0x3F);
    try std.testing.expect((ppu.registers.scroll_unit.t.read() & 0x7F00) == 0x3F00);
    try std.testing.expect(ppu.registers.scroll_unit.w == true);

    ppu.writeRegister(6, 0x21);
    try std.testing.expect((ppu.registers.scroll_unit.t.read() & 0x00FF) == 0x21);
    try std.testing.expect(ppu.registers.scroll_unit.v.read() == ppu.registers.scroll_unit.t.read());
    try std.testing.expect(ppu.registers.scroll_unit.w == false);
}

test "ScrollUnit incrementHorizontal wraps correctly" {
    const allocator = std.testing.allocator;
    var cartridge = try buildTestRom(allocator, &.{}, 0x8000);
    defer cartridge.deinit(allocator);

    var ppu = PPU.init(&cartridge);
    // ppu.writeRegister(5, 0b11111000); // binary: 11111 000 → coarse_x=31, x=0
    ppu.registers.scroll_unit.v.coarse_x = 31;
    ppu.registers.scroll_unit.v.nametable = 0b00;

    ppu.registers.scroll_unit.incrementHorizontal();
    try std.testing.expect(ppu.registers.scroll_unit.v.coarse_x == 0);
    try std.testing.expect(ppu.registers.scroll_unit.v.nametable == 0b01);
}
