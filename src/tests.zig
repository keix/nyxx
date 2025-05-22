const std = @import("std");
const CPU = @import("6502.zig").CPU;
const PPU = @import("ppu.zig").PPU;
const Bus = @import("bus.zig").Bus;

/// Test-only helper to build a ROM image in memory
pub fn buildTestRom(allocator: std.mem.Allocator, program: []const u8, reset_vector: u16) ![]u8 {
    var rom = try allocator.alloc(u8, 65536);
    @memset(rom, 0);

    // Copy program
    for (program, 0..) |byte, i| {
        rom[reset_vector + @as(u16, @intCast(i))] = byte;
    }

    // Set reset vector
    rom[0xFFFC] = @as(u8, @intCast(reset_vector & 0x00FF));
    rom[0xFFFD] = @as(u8, @intCast(reset_vector >> 8));

    return rom;
}

test "LDA loads immediate value into A and updates flags" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0xA9, 0x00 }, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    _ = cpu.step();

    try std.testing.expect(cpu.registers.a == 0x00);
    try std.testing.expect(cpu.registers.flags.z == true);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "TAX transfers A to X" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{0xAA}, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    cpu.registers.a = 0x42;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.x == 0x42);
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "INX increments X and updates flags" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{0xE8}, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    cpu.registers.x = 0x7F;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.x == 0x80);
    try std.testing.expect(cpu.registers.flags.n == true);
    try std.testing.expect(cpu.registers.flags.z == false);
}

test "DEX decrements X and sets flags" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{0xCA}, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    cpu.registers.x = 1;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.x == 0);
    try std.testing.expect(cpu.registers.flags.z == true);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "CMP compares A with immediate value" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0xC9, 0x42 }, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    cpu.registers.a = 0x42;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.flags.z == true);
    try std.testing.expect(cpu.registers.flags.c == true);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "LDY loads immediate value into Y" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0xA0, 0x7F }, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    _ = cpu.step();

    try std.testing.expect(cpu.registers.y == 0x7F);
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "TAY transfers A to Y and updates flags" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{0xA8}, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    cpu.registers.a = 0x80;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.y == 0x80);
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == true);
}

test "INY increments Y and updates flags" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{0xC8}, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    cpu.registers.y = 0xFF;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.y == 0x00);
    try std.testing.expect(cpu.registers.flags.z == true);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "DEY decrements Y and updates flags" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{0x88}, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    cpu.registers.y = 0x01;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.y == 0x00);
    try std.testing.expect(cpu.registers.flags.z == true);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "BEQ branches if Z flag is set" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0xF0, 0x02 }, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    cpu.registers.flags.z = true;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.pc == 0x8004);
}

test "BEQ does not branch if Z flag is clear" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0xF0, 0x02 }, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    cpu.registers.flags.z = false;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.pc == 0x8000 + 0x02); // only offset fetch
}

test "BEQ takes branch and crosses page boundary (+2 cycles)" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0xF0, 0x01 }, 0x80FD);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);
    cpu.registers.flags.z = true;

    const cycles = cpu.step();

    try std.testing.expect(cpu.registers.pc == 0x8100); // expected jump
    try std.testing.expect(cycles == 4); // 2 base + 2 extra (page crossed)
}

test "BNE branches if Z flag is clear" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0xD0, 0x02 }, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    cpu.registers.flags.z = false;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.pc == 0x8004);
}

test "BNE does not branch if Z flag is set" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0xD0, 0x02 }, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    cpu.registers.flags.z = true;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.pc == 0x8000 + 0x02);
}

test "BPL branches if N flag is clear" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0x10, 0x02 }, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);
    cpu.registers.flags.n = false;

    _ = cpu.step();
    try std.testing.expect(cpu.registers.pc == 0x8004);
}

test "BPL does not branch if N flag is set" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0x10, 0x02 }, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);
    cpu.registers.flags.n = true;

    _ = cpu.step();
    try std.testing.expect(cpu.registers.pc == 0x8002);
}

test "BPL takes branch and crosses page boundary (+2 cycles)" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0x10, 0x02 }, 0x80FD);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);
    cpu.registers.flags.n = false;

    const cycles = cpu.step();
    try std.testing.expect(cpu.registers.pc == 0x8101);
    try std.testing.expect(cycles == 4); // base 2 + page_crossed 2
}

test "BMI branches if N flag is set" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0x30, 0x02 }, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);
    cpu.registers.flags.n = true;

    _ = cpu.step();
    try std.testing.expect(cpu.registers.pc == 0x8004);
}

test "BCC branches if C flag is clear" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0x90, 0x02 }, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);
    cpu.registers.flags.c = false;

    _ = cpu.step();
    try std.testing.expect(cpu.registers.pc == 0x8004);
}

test "BCS branches if C flag is set" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0xB0, 0x02 }, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);
    cpu.registers.flags.c = true;

    _ = cpu.step();
    try std.testing.expect(cpu.registers.pc == 0x8004);
}

test "BVC branches if V flag is clear" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0x50, 0x02 }, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);
    cpu.registers.flags.v = false;

    _ = cpu.step();
    try std.testing.expect(cpu.registers.pc == 0x8004);
}

test "BVS branches if V flag is set" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0x70, 0x02 }, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);
    cpu.registers.flags.v = true;

    _ = cpu.step();
    try std.testing.expect(cpu.registers.pc == 0x8004);
}

test "PHA pushes A onto stack" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{0x48}, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    cpu.registers.a = 0xAB;
    cpu.registers.s = 0xFD;
    _ = cpu.step();

    try std.testing.expect(bus.read(0x01FD) == 0xAB);
    try std.testing.expect(cpu.registers.s == 0xFC);
}

test "PLA pulls from stack into A and updates flags" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{0x68}, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
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
    const rom = try buildTestRom(allocator, &.{0x08}, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
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
    const rom = try buildTestRom(allocator, &.{0x28}, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
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
    const rom = try buildTestRom(allocator, &.{0x38}, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    cpu.registers.flags.c = false;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.flags.c == true);
}

test "CLC clears carry flag" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{0x18}, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    cpu.registers.flags.c = true;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.flags.c == false);
}

test "SEI sets interrupt disable flag" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{0x78}, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    cpu.registers.flags.i = false;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.flags.i == true);
}

test "CLI clears interrupt disable flag" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{0x58}, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    cpu.registers.flags.i = true;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.flags.i == false);
}

test "STA stores A into zero page" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0x85, 0x10 }, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    cpu.registers.a = 0x42;
    _ = cpu.step();

    try std.testing.expect(bus.read(0x0010) == 0x42);
}

test "STA stores A into absolute RAM address" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0x8D, 0x00, 0x10 }, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    cpu.registers.a = 0x99;
    _ = cpu.step();

    try std.testing.expect(bus.read(0x1000) == 0x99);
}

test "STY stores Y into zero page" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0x84, 0x10 }, 0x8000); // STY $10
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);
    cpu.registers.y = 0x77;

    _ = cpu.step();

    try std.testing.expect(bus.read(0x0010) == 0x77);
}

test "STY stores Y into absolute address" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0x8C, 0x34, 0x12 }, 0x8000); // STY $1234
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);
    cpu.registers.y = 0x88;

    _ = cpu.step();

    try std.testing.expect(bus.read(0x1234) == 0x88);
}

test "STX stores X into zero page" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0x86, 0x20 }, 0x8000); // STX $20
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);
    cpu.registers.x = 0x55;

    _ = cpu.step();

    try std.testing.expect(bus.read(0x0020) == 0x55);
}

test "STX stores X into absolute address" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0x8E, 0x34, 0x12 }, 0x8000); // STX $1234
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);
    cpu.registers.x = 0xA5;

    _ = cpu.step();

    try std.testing.expect(bus.read(0x1234) == 0xA5);
}

test "LDX loads immediate value into X" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0xA2, 0x10 }, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    _ = cpu.step();

    try std.testing.expectEqual(@as(u8, 0x10), cpu.registers.x);
}

test "BIT sets Z flag if A & M == 0" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0x24, 0x10 }, 0x8000); // BIT $10
    defer allocator.free(rom);

    var bus = Bus.init(rom);
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
    const rom = try buildTestRom(allocator, &.{ 0x2C, 0x34, 0x12 }, 0x8000); // BIT $1234
    defer allocator.free(rom);

    var bus = Bus.init(rom);
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
    const rom = try buildTestRom(allocator, &.{0x8A}, 0x8000); // TXA
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    cpu.registers.x = 0x00;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.a == 0x00);
    try std.testing.expect(cpu.registers.flags.z == true);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "TYA transfers Y to A and updates flags" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{0x98}, 0x8000); // TYA
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    cpu.registers.y = 0xFF;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.a == 0xFF);
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == true);
}

test "TSX transfers stack pointer to X and updates flags" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{0xBA}, 0x8000); // TSX
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    cpu.registers.s = 0x00;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.x == 0x00);
    try std.testing.expect(cpu.registers.flags.z == true);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "TXS transfers X to stack pointer" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{0x9A}, 0x8000); // TXS
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    cpu.registers.x = 0xFE;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.s == 0xFE);
}

test "INC increments value at memory and sets Z/N flags" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0xE6, 0x10 }, 0x8000); // INC $10
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);
    bus.write(0x0010, 0xFF);

    _ = cpu.step();

    try std.testing.expect(bus.read(0x0010) == 0x00);
    try std.testing.expect(cpu.registers.flags.z == true);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "DEC decrements value at memory and sets Z/N flags" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0xC6, 0x10 }, 0x8000); // DEC $10
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);
    bus.write(0x0010, 0x01);

    _ = cpu.step();

    try std.testing.expect(bus.read(0x0010) == 0x00);
    try std.testing.expect(cpu.registers.flags.z == true);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "JMP absolute sets PC to target" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0x4C, 0x00, 0x90 }, 0x8000); // JMP $9000
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    _ = cpu.step();
    try std.testing.expect(cpu.registers.pc == 0x9000);
}

test "JMP indirect uses address stored in memory (6502 page bug case)" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0x6C, 0xFF, 0x00 }, 0x8000); // JMP ($00FF)
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    bus.write(0x00FF, 0x34); // LSB
    bus.write(0x0000, 0x12); // MSB (page wrap)

    _ = cpu.step();
    try std.testing.expect(cpu.registers.pc == 0x1234);
}

test "JSR pushes return address and jumps" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0x20, 0x00, 0x90 }, 0x8000); // JSR $9000
    defer allocator.free(rom);

    var bus = Bus.init(rom);
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
    const rom = try buildTestRom(allocator, program, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    try std.testing.expect(cpu.step() == 2); // LDX
    const cycles = cpu.step(); // LDA Absolute,X
    try std.testing.expect(cycles == 5); // +1 cycle due to page crossing
}

test "RTS pulls return address and jumps to PC+1" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{0x60}, 0x8000); // RTS opcode
    defer allocator.free(rom);

    var bus = Bus.init(rom);
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
    const rom = try buildTestRom(allocator, &.{0x40}, 0x8000); // RTI
    defer allocator.free(rom);

    var bus = Bus.init(rom);
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
    const rom = try buildTestRom(allocator, &.{ 0x69, 0x10 }, 0x8000); // ADC #$10
    defer allocator.free(rom);

    var bus = Bus.init(rom);
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
    const rom = try buildTestRom(allocator, &.{ 0x65, 0x10 }, 0x8000); // ADC $10
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);
    bus.write(0x0010, 0x05);

    cpu.registers.a = 0x03;
    cpu.registers.flags.c = false;

    _ = cpu.step();

    try std.testing.expect(cpu.registers.a == 0x08);
}

test "ADC zero page,X" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0x75, 0x10 }, 0x8000); // ADC $10,X
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);
    cpu.registers.x = 0x01;
    bus.write(0x0011, 0x02);

    cpu.registers.a = 0x01;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.a == 0x03);
}

test "ADC absolute" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0x6D, 0x34, 0x12 }, 0x8000); // ADC $1234
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);
    bus.write(0x1234, 0x10);

    cpu.registers.a = 0x01;
    _ = cpu.step();

    try std.testing.expect(cpu.registers.a == 0x11);
}

test "ADC absolute,X with page crossing (in RAM)" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0x7D, 0xFF, 0x00 }, 0x8000); // ADC $00FF,X
    defer allocator.free(rom);

    var bus = Bus.init(rom);
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
    const rom = try buildTestRom(allocator, &.{ 0x79, 0x00, 0x02 }, 0x8000); // ADC $0200,Y
    defer allocator.free(rom);

    var bus = Bus.init(rom);
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
    const rom = try buildTestRom(allocator, &.{ 0x71, 0x10 }, 0x8000); // ADC ($10),Y
    defer allocator.free(rom);

    var bus = Bus.init(rom);
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
    const rom = try buildTestRom(allocator, &.{ 0xED, 0x03, 0x80, 0x02 }, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    cpu.registers.a = 0x05;
    cpu.registers.flags.c = true;

    const cycles = cpu.step();
    try std.testing.expect(cpu.registers.a == 0x03);
    try std.testing.expect(cycles == 4);
}

test "SBC absolute,X" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0xFD, 0x04, 0x80, 0x00, 0x00, 0x00, 0x02 }, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
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
    const rom = try buildTestRom(allocator, &.{ 0xE5, 0x10 }, 0x8000); // SBC $10
    defer allocator.free(rom);

    var bus = Bus.init(rom);
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
    const rom = try buildTestRom(allocator, &.{ 0xF5, 0x10 }, 0x8000); // SBC $10,X
    defer allocator.free(rom);

    var bus = Bus.init(rom);
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
    const rom = try buildTestRom(allocator, &.{ 0xF1, 0x10 }, 0x8000); // SBC ($10),Y
    defer allocator.free(rom);

    var bus = Bus.init(rom);
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
    const rom = try buildTestRom(allocator, &.{ 0xE9, 0x02 }, 0x8000); // SBC #$02
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    cpu.registers.a = 0x05;
    cpu.registers.flags.c = true; // no borrow

    const cycles = cpu.step();
    try std.testing.expect(cpu.registers.a == 0x03); // 0x05 - 0x02 = 0x03
    try std.testing.expect(cycles == 2);
}

// Test for STA with PPU registers
test "STA stores A into $2000 and updates PPUCTRL" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0x8D, 0x00, 0x20 }, 0x8000); // STA $2000
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    cpu.registers.a = 0b10100000;
    _ = cpu.step();

    try std.testing.expectEqual(@as(u8, 0b10100000), bus.ppu.registers.ctrl);
}

test "STA stores A into $2001 and updates PPUMASK" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0x8D, 0x01, 0x20 }, 0x8000); // STA $2001
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    cpu.registers.a = 0b00011111;
    _ = cpu.step();

    try std.testing.expectEqual(@as(u8, 0b00011111), bus.ppu.registers.mask.read());
}

test "BIT $2002 reflects PPU status VBlank and clears it" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0x2C, 0x02, 0x20 }, 0x8000); // BIT $2002
    defer allocator.free(rom);

    var bus = Bus.init(rom);
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
