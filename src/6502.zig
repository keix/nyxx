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
        // Convert the flags to a byte representation
        return (@as(u8, @intFromBool(self.c)) << 0) |
            (@as(u8, @intFromBool(self.z)) << 1) |
            (@as(u8, @intFromBool(self.i)) << 2) |
            (@as(u8, @intFromBool(self.d)) << 3) |
            (@as(u8, @intFromBool(self.b)) << 4) |
            0b00100000 | // bit 5 always set
            (@as(u8, @intFromBool(self.v)) << 6) |
            (@as(u8, @intFromBool(self.n)) << 7);
    }

    pub fn fromByte(byte: u8) Flags {
        // Convert a byte representation back to flags
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
            .BEQ => self.opBeq(),
            .BNE => self.opBne(),
            .PHA => self.opPha(),
            .PLA => self.opPla(),
            .PHP => self.opPhp(),
            .PLP => self.opPlp(),
            .SEC => self.opSec(),
            .CLC => self.opClc(),
            .SEI => self.opSei(),
            .CLI => self.opCli(),
            .STA => self.opSta(instr.addressing_mode),
            // Add more opcodes as needed
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

    inline fn compare(self: *CPU, reg: u8, value: u8) void {
        const result = reg -% value;
        self.registers.flags.z = (reg == value);
        self.registers.flags.c = (reg >= value);
        self.registers.flags.n = (result & 0x80) != 0;
    }

    inline fn push(self: *CPU, value: u8) void {
        self.writeMemory(0x0100 | @as(u16, self.registers.s), value);
        self.registers.s -%= 1;
    }

    inline fn pop(self: *CPU) u8 {
        self.registers.s +%= 1;
        return self.readMemory(0x0100 | @as(u16, self.registers.s));
    }

    // Opcode implementations
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

    inline fn opBeq(self: *CPU) void {
        const offset = @as(i8, @bitCast(self.fetchU8()));
        if (self.registers.flags.z) {
            self.registers.pc +%= @as(u16, @intCast(offset));
        }
    }

    inline fn opBne(self: *CPU) void {
        const offset = @as(i8, @bitCast(self.fetchU8()));
        if (!self.registers.flags.z) {
            self.registers.pc +%= @as(u16, @intCast(offset));
        }
    }

    inline fn opPha(self: *CPU) void {
        self.push(self.registers.a);
    }

    inline fn opPla(self: *CPU) void {
        const value = self.pop();
        self.registers.a = value;
        self.updateZN(value);
    }

    inline fn opPhp(self: *CPU) void {
        var flags = self.registers.flags.toByte();
        flags |= 0b00110000;
        self.push(flags);
    }

    inline fn opPlp(self: *CPU) void {
        const flags = self.pop();
        self.registers.flags = Flags.fromByte(flags);
    }

    inline fn opSec(self: *CPU) void {
        self.registers.flags.c = true;
    }

    inline fn opClc(self: *CPU) void {
        self.registers.flags.c = false;
    }

    inline fn opSei(self: *CPU) void {
        self.registers.flags.i = true;
    }

    inline fn opCli(self: *CPU) void {
        self.registers.flags.i = false;
    }

    inline fn opSta(self: *CPU, addressing_mode: Opcode.AddressingMode) void {
        const addr: u16 = switch (addressing_mode) {
            .zero_page => @as(u16, self.fetchU8()),
            .absolute => self.fetchU16(),
            else => unreachable,
        };

        self.writeMemory(addr, self.registers.a);
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

test "BEQ branches if Z flag is set" {
    var bus = Bus.init();
    var cpu = CPU.init(&bus);

    cpu.registers.flags.z = true;
    bus.loadProgram(&.{ 0xF0, 0x02 }, 0x0000); // BEQ +2
    cpu.step();

    try std.testing.expect(cpu.registers.pc == 0x0002 + 0x02); // PC after fetch + offset
}

test "BEQ does not branch if Z flag is clear" {
    var bus = Bus.init();
    var cpu = CPU.init(&bus);

    cpu.registers.flags.z = false;
    bus.loadProgram(&.{ 0xF0, 0x02 }, 0x0000); // BEQ +2
    cpu.step();

    try std.testing.expect(cpu.registers.pc == 0x0002); // only offset fetch
}

test "BNE branches if Z flag is clear" {
    var bus = Bus.init();
    var cpu = CPU.init(&bus);

    cpu.registers.flags.z = false;
    bus.loadProgram(&.{ 0xD0, 0x02 }, 0x0000); // BNE +2
    cpu.step();

    try std.testing.expect(cpu.registers.pc == 0x0002 + 0x02);
}

test "BNE does not branch if Z flag is set" {
    var bus = Bus.init();
    var cpu = CPU.init(&bus);

    cpu.registers.flags.z = true;
    bus.loadProgram(&.{ 0xD0, 0x02 }, 0x0000); // BNE +2
    cpu.step();

    try std.testing.expect(cpu.registers.pc == 0x0002);
}

test "push writes to stack and decrements S" {
    var bus = Bus.init();
    var cpu = CPU.init(&bus);

    cpu.registers.s = 0xFD;
    cpu.push(0x42);

    try std.testing.expect(cpu.registers.s == 0xFC);
    try std.testing.expect(bus.read(0x01FD) == 0x42);
}

test "pop reads from stack and increments S" {
    var bus = Bus.init();
    var cpu = CPU.init(&bus);

    bus.write(0x01FD, 0x99);
    cpu.registers.s = 0xFC;
    const value = cpu.pop();

    try std.testing.expect(cpu.registers.s == 0xFD);
    try std.testing.expect(value == 0x99);
}

test "PHA pushes A onto stack" {
    var bus = Bus.init();
    var cpu = CPU.init(&bus);

    cpu.registers.a = 0xAB;
    cpu.registers.s = 0xFD;
    bus.loadProgram(&.{0x48}, 0x0000); // PHA
    cpu.step();

    try std.testing.expect(bus.read(0x01FD) == 0xAB);
    try std.testing.expect(cpu.registers.s == 0xFC);
}

test "PLA pulls from stack into A and updates flags" {
    var bus = Bus.init();
    var cpu = CPU.init(&bus);

    cpu.registers.s = 0xFC;
    bus.write(0x01FD, 0x80); // value with negative flag
    bus.loadProgram(&.{0x68}, 0x0000); // PLA
    cpu.step();

    try std.testing.expect(cpu.registers.a == 0x80);
    try std.testing.expect(cpu.registers.flags.n == true);
    try std.testing.expect(cpu.registers.flags.z == false);
    try std.testing.expect(cpu.registers.s == 0xFD);
}

test "PHP pushes processor flags onto the stack" {
    var bus = Bus.init();
    var cpu = CPU.init(&bus);

    cpu.registers.flags = .{ .n = true, .z = true, .c = true }; // sample flags
    cpu.registers.s = 0xFD;
    bus.loadProgram(&.{0x08}, 0x0000); // PHP
    cpu.step();

    const pushed = bus.read(0x01FD);
    try std.testing.expect((pushed & 0b10000000) != 0); // N
    try std.testing.expect((pushed & 0b00000010) != 0); // Z
    try std.testing.expect((pushed & 0b00000001) != 0); // C
    try std.testing.expect((pushed & 0b00110000) == 0b00110000); // B + bit 5
    try std.testing.expect(cpu.registers.s == 0xFC);
}

test "PLP pulls flags from stack" {
    var bus = Bus.init();
    var cpu = CPU.init(&bus);

    bus.write(0x01FD, 0b11001101); // set various flags
    cpu.registers.s = 0xFC;
    bus.loadProgram(&.{0x28}, 0x0000); // PLP
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
    var bus = Bus.init();
    var cpu = CPU.init(&bus);

    cpu.registers.flags.c = false;
    bus.loadProgram(&.{0x38}, 0x0000); // SEC
    cpu.step();

    try std.testing.expect(cpu.registers.flags.c == true);
}

test "CLC clears carry flag" {
    var bus = Bus.init();
    var cpu = CPU.init(&bus);

    cpu.registers.flags.c = true;
    bus.loadProgram(&.{0x18}, 0x0000); // CLC
    cpu.step();

    try std.testing.expect(cpu.registers.flags.c == false);
}

test "SEI sets interrupt disable flag" {
    var bus = Bus.init();
    var cpu = CPU.init(&bus);

    cpu.registers.flags.i = false;
    bus.loadProgram(&.{0x78}, 0x0000); // SEI
    cpu.step();

    try std.testing.expect(cpu.registers.flags.i == true);
}

test "CLI clears interrupt disable flag" {
    var bus = Bus.init();
    var cpu = CPU.init(&bus);

    cpu.registers.flags.i = true;
    bus.loadProgram(&.{0x58}, 0x0000); // CLI
    cpu.step();

    try std.testing.expect(cpu.registers.flags.i == false);
}

test "STA stores A into zero page" {
    var bus = Bus.init();
    var cpu = CPU.init(&bus);

    cpu.registers.a = 0x42;
    bus.loadProgram(&.{ 0x85, 0x10 }, 0x0000); // STA $10
    cpu.step();

    try std.testing.expect(bus.read(0x0010) == 0x42);
}

test "STA stores A into absolute address" {
    var bus = Bus.init();
    var cpu = CPU.init(&bus);

    cpu.registers.a = 0x99;
    bus.loadProgram(&.{ 0x8D, 0x00, 0x80 }, 0x0000); // STA $8000
    cpu.step();

    try std.testing.expect(bus.read(0x8000) == 0x99);
}
