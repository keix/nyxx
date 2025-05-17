const std = @import("std");
const Bus = @import("bus.zig").Bus;
const Opcode = @import("opcode.zig");

const Flags = struct {
    n: bool = false, // Negative
    v: bool = false, // Overflow
    b: bool = false, // Break
    d: bool = false, // Decimal (unused in NES)
    i: bool = false, // Interrupt Disable
    z: bool = false, // Zero
    c: bool = false, // Carry

    pub fn toByte(self: Flags) u8 {
        return (@as(u8, self.c) << 0) |
            (@as(u8, self.z) << 1) |
            (@as(u8, self.i) << 2) |
            (@as(u8, self.d) << 3) |
            (@as(u8, self.b) << 4) |
            0b00100000 | // bit 5 always set
            (@as(u8, self.v) << 6) |
            (@as(u8, self.n) << 7);
    }

    pub fn fromByte(byte: u8) Flags {
        return Flags{
            .c = (byte & 0x01) != 0,
            .z = (byte & 0x02) != 0,
            .i = (byte & 0x04) != 0,
            .d = (byte & 0x08) != 0,
            .b = (byte & 0x10) != 0,
            .v = (byte & 0x40) != 0,
            .n = (byte & 0x80) != 0,
        };
    }
};

const Registers = struct {
    a: u8 = 0,
    x: u8 = 0,
    y: u8 = 0,
    s: u8 = 0xFD,
    pc: u16 = 0x0000,
    flags: Flags = .{},
};

pub const CPU = struct {
    registers: Registers = .{},
    bus: *Bus,

    pub fn init(bus: *Bus) CPU {
        return CPU{
            .bus = bus,
            .registers = Registers{},
        };
    }

    pub fn readMemory(self: *CPU, addr: u16) u8 {
        return self.bus.read(addr);
    }

    pub fn writeMemory(self: *CPU, addr: u16, data: u8) void {
        self.bus.write(addr, data);
    }

    pub fn step(self: *CPU) void {
        const opcode = self.fetchU8();
        const instr = Opcode.instruction_table[opcode];

        self.execute(instr);
    }

    fn execute(self: *CPU, instr: Opcode.Instruction) void {
        switch (instr.mnemonic) {
            .LDA => self.opLda(instr.addressing_mode),
            .TAX => self.opTax(),
            .INX => self.opInx(),
            .DEX => self.opDex(),
            .CMP => self.opCmp(instr.addressing_mode),
            .LDY => self.opLdy(instr.addressing_mode),
            .TAY => self.opTay(),
            .INY => self.opIny(),
            .DEY => self.opDey(),
            else => {
                std.debug.print("Unimplemented mnemonic: {}\n", .{instr.mnemonic});
            },
        }
    }

    inline fn fetchU8(self: *CPU) u8 {
        const value = self.readMemory(self.registers.pc);
        self.registers.pc +%= 1;

        return value;
    }

    inline fn fetchU16(self: *CPU) u16 {
        const low = @as(u8, self.fetchU8());
        const high = @as(u8, self.fetchU8());

        return (@as(u16, high) << 8) | @as(u16, low);
    }

    inline fn updateZN(self: *CPU, value: u8) void {
        self.registers.flags.z = (value == 0);
        self.registers.flags.n = (value & 0x80) != 0;
    }

    inline fn setCarry(self: *CPU, enabled: bool) void {
        self.registers.flags.c = enabled;
    }

    inline fn setOverflow(self: *CPU, enabled: bool) void {
        self.registers.flags.v = enabled;
    }

    inline fn compare(self: *CPU, reg: u8, value: u8) void {
        const result = reg -% value;
        self.registers.flags.z = (reg == value);
        self.registers.flags.c = (reg >= value);
        self.registers.flags.n = (result & 0x80) != 0;
    }

    inline fn opLda(self: *CPU, addressing_mode: Opcode.AddressingMode) void {
        const value = switch (addressing_mode) {
            .immediate => self.fetchU8(),
            .zero_page => self.readMemory(self.fetchU8()),
            .absolute => self.readMemory(self.fetchU16()),
            else => unreachable,
        };

        self.registers.a = value;
        self.updateZN(self.registers.a);
    }

    inline fn opTax(self: *CPU) void {
        self.registers.x = self.registers.a;
        self.updateZN(self.registers.x);
    }

    inline fn opInx(self: *CPU) void {
        self.registers.x +%= 1;
        self.updateZN(self.registers.x);
    }

    inline fn opDex(self: *CPU) void {
        self.registers.x -%= 1;
        self.updateZN(self.registers.x);
    }

    inline fn opCmp(self: *CPU, addressing_mode: Opcode.AddressingMode) void {
        const value = switch (addressing_mode) {
            .immediate => self.fetchU8(),
            .zero_page => self.readMemory(self.fetchU8()),
            .absolute => self.readMemory(self.fetchU16()),
            else => unreachable,
        };

        self.compare(self.registers.a, value);
    }

    inline fn opLdy(self: *CPU, addressing_mode: Opcode.AddressingMode) void {
        const value = switch (addressing_mode) {
            .immediate => self.fetchU8(),
            .zero_page => self.readMemory(self.fetchU8()),
            .absolute => self.readMemory(self.fetchU16()),
            else => unreachable,
        };

        self.registers.y = value;
        self.updateZN(self.registers.y);
    }

    inline fn opTay(self: *CPU) void {
        self.registers.y = self.registers.a;
        self.updateZN(self.registers.y);
    }

    inline fn opIny(self: *CPU) void {
        self.registers.y +%= 1;
        self.updateZN(self.registers.y);
    }

    inline fn opDey(self: *CPU) void {
        self.registers.y -%= 1;
        self.updateZN(self.registers.y);
    }
};

test "LDA loads immediate value into A and updates flags" {
    var bus = Bus.init();
    var cpu = CPU.init(&bus);

    bus.loadProgram(&.{ 0xA9, 0x00 }, 0x0000); // LDA #$00
    cpu.step();

    try std.testing.expect(cpu.registers.a == 0x00);
    try std.testing.expect(cpu.registers.flags.z == true);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "TAX transfers A to X" {
    var bus = Bus.init();
    var cpu = CPU.init(&bus);

    cpu.registers.a = 0x42;
    bus.loadProgram(&.{0xAA}, 0x0000); // TAX
    cpu.step();

    try std.testing.expect(cpu.registers.x == 0x42);
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "INX increments X and updates flags" {
    var bus = Bus.init();
    var cpu = CPU.init(&bus);

    bus.loadProgram(&.{0xE8}, 0x0000); // INX
    cpu.registers.x = 0x7F;
    cpu.step();

    try std.testing.expect(cpu.registers.x == 0x80);
    try std.testing.expect(cpu.registers.flags.n == true);
    try std.testing.expect(cpu.registers.flags.z == false);
}

test "DEX decrements X and sets flags" {
    var bus = Bus.init();
    var cpu = CPU.init(&bus);

    cpu.registers.x = 1;
    bus.loadProgram(&.{0xCA}, 0x0000); // DEX
    cpu.step();

    try std.testing.expect(cpu.registers.x == 0);
    try std.testing.expect(cpu.registers.flags.z == true);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "CMP compares A with immediate value" {
    var bus = Bus.init();
    var cpu = CPU.init(&bus);

    cpu.registers.a = 0x42;
    bus.loadProgram(&.{ 0xC9, 0x42 }, 0x0000); // CMP #$42
    cpu.step();

    try std.testing.expect(cpu.registers.flags.z == true);
    try std.testing.expect(cpu.registers.flags.c == true);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "LDY loads immediate value into Y" {
    var bus = Bus.init();
    var cpu = CPU.init(&bus);

    bus.loadProgram(&.{ 0xA0, 0x7F }, 0x0000); // LDY #$7F
    cpu.step();

    try std.testing.expect(cpu.registers.y == 0x7F);
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "TAY transfers A to Y and updates flags" {
    var bus = Bus.init();
    var cpu = CPU.init(&bus);

    cpu.registers.a = 0x80;
    bus.loadProgram(&.{0xA8}, 0x0000); // TAY
    cpu.step();

    try std.testing.expect(cpu.registers.y == 0x80);
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.flags.n == true);
}

test "INY increments Y and updates flags" {
    var bus = Bus.init();
    var cpu = CPU.init(&bus);

    cpu.registers.y = 0xFF;
    bus.loadProgram(&.{0xC8}, 0x0000); // INY
    cpu.step();

    try std.testing.expect(cpu.registers.y == 0x00);
    try std.testing.expect(cpu.registers.flags.z == true);
    try std.testing.expect(cpu.registers.flags.n == false);
}

test "DEY decrements Y and updates flags" {
    var bus = Bus.init();
    var cpu = CPU.init(&bus);

    cpu.registers.y = 0x01;
    bus.loadProgram(&.{0x88}, 0x0000); // DEY
    cpu.step();

    try std.testing.expect(cpu.registers.y == 0x00);
    try std.testing.expect(cpu.registers.flags.z == true);
    try std.testing.expect(cpu.registers.flags.n == false);
}
