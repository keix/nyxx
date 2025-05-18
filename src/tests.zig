const std = @import("std");
const CPU = @import("6502.zig").CPU;
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

    cpu.step();

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
    cpu.step();

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
    cpu.step();

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
    cpu.step();

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
    cpu.step();

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

    cpu.step();

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
    cpu.step();

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
    cpu.step();

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
    cpu.step();

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
    cpu.step();

    try std.testing.expect(cpu.registers.pc == 0x8000 + 0x02 + 0x02); // PC after fetch + offset
}

test "BEQ does not branch if Z flag is clear" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0xF0, 0x02 }, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    cpu.registers.flags.z = false;
    cpu.step();

    try std.testing.expect(cpu.registers.pc == 0x8000 + 0x02); // only offset fetch
}

test "BNE branches if Z flag is clear" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0xD0, 0x02 }, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    cpu.registers.flags.z = false;
    cpu.step();

    try std.testing.expect(cpu.registers.pc == 0x8000 + 0x02 + 0x02);
}

test "BNE does not branch if Z flag is set" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0xD0, 0x02 }, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    cpu.registers.flags.z = true;
    cpu.step();

    try std.testing.expect(cpu.registers.pc == 0x8000 + 0x02);
}

test "PHA pushes A onto stack" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{0x48}, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    cpu.registers.a = 0xAB;
    cpu.registers.s = 0xFD;
    cpu.step();

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
    cpu.step();

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
    cpu.step();

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
    cpu.step();

    try std.testing.expect(cpu.registers.flags.n == true);
    try std.testing.expect(cpu.registers.flags.v == true);
    // try std.testing.expect(cpu.registers.flags.b == true);
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
    cpu.step();

    try std.testing.expect(cpu.registers.flags.c == true);
}

test "CLC clears carry flag" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{0x18}, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    cpu.registers.flags.c = true;
    cpu.step();

    try std.testing.expect(cpu.registers.flags.c == false);
}

test "SEI sets interrupt disable flag" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{0x78}, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    cpu.registers.flags.i = false;
    cpu.step();

    try std.testing.expect(cpu.registers.flags.i == true);
}

test "CLI clears interrupt disable flag" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{0x58}, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    cpu.registers.flags.i = true;
    cpu.step();

    try std.testing.expect(cpu.registers.flags.i == false);
}

test "STA stores A into zero page" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0x85, 0x10 }, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    cpu.registers.a = 0x42;
    cpu.step();

    try std.testing.expect(bus.read(0x0010) == 0x42);
}

test "STA stores A into absolute RAM address" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0x8D, 0x00, 0x10 }, 0x8000);
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);

    cpu.registers.a = 0x99;
    cpu.step();

    try std.testing.expect(bus.read(0x1000) == 0x99);
}

test "STY stores Y into zero page" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0x84, 0x10 }, 0x8000); // STY $10
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);
    cpu.registers.y = 0x77;

    cpu.step();

    try std.testing.expect(bus.read(0x0010) == 0x77);
}

test "STY stores Y into absolute address" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0x8C, 0x00, 0x20 }, 0x8000); // STY $2000
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);
    cpu.registers.y = 0x88;

    cpu.step();

    try std.testing.expect(bus.read(0x2000) == 0x88);
}

test "STX stores X into zero page" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0x86, 0x20 }, 0x8000); // STX $20
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);
    cpu.registers.x = 0x55;

    cpu.step();

    try std.testing.expect(bus.read(0x0020) == 0x55);
}

test "STX stores X into absolute address" {
    const allocator = std.testing.allocator;
    const rom = try buildTestRom(allocator, &.{ 0x8E, 0x34, 0x12 }, 0x8000); // STX $1234
    defer allocator.free(rom);

    var bus = Bus.init(rom);
    var cpu = CPU.init(&bus);
    cpu.registers.x = 0xA5;

    cpu.step();

    try std.testing.expect(bus.read(0x1234) == 0xA5);
}
