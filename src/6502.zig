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
    // 6502 registers
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
        var cpu = CPU{
            .bus = bus,
            .registers = Registers{},
        };

        cpu.reset();
        return cpu;
    }

    fn reset(self: *CPU) void {
        const low = self.readMemory(0xFFFC);
        const high = self.readMemory(0xFFFD);
        self.registers.pc = (@as(u16, high) << 8) | low;
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

        std.debug.print("PC: 0x{X:0>4}, opcode: 0x{X:0>2}\n", .{ self.registers.pc, opcode });
        self.execute(instr);
    }

    fn execute(self: *CPU, instr: Opcode.Instruction) void {
        switch (instr.mnemonic) {
            .LDA => self.opLda(instr.addressing_mode),
            .TAX => self.opTax(),
            .INX => self.opInx(),
            .DEX => self.opDex(),
            .CMP => self.opCmp(instr.addressing_mode),
            .LDX => self.opLdx(instr.addressing_mode),
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
            .STX => self.opStx(instr.addressing_mode),
            .STY => self.opSty(instr.addressing_mode),
            .BIT => self.opBit(instr.addressing_mode),
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

    inline fn readFrom(self: *CPU, mode: Opcode.AddressingMode) u8 {
        const addr: u16 = switch (mode) {
            .immediate => return self.fetchU8(),
            .zero_page => self.getZeroPage(),
            .zero_page_x => self.getZeroPageX(),
            .zero_page_y => self.getZeroPageY(),
            .absolute => self.getAbsolute(),
            .absolute_x => self.getAbsoluteX(),
            .absolute_y => self.getAbsoluteY(),
            .indirect_x => self.getIndirectX(),
            .indirect_y => self.getIndirectY(),
            else => unreachable,
        };
        return self.readMemory(addr);
    }

    inline fn writeTo(self: *CPU, mode: Opcode.AddressingMode, value: u8) void {
        const addr: u16 = switch (mode) {
            .zero_page => self.getZeroPage(),
            .zero_page_x => self.getZeroPageX(),
            .zero_page_y => self.getZeroPageY(),
            .absolute => self.getAbsolute(),
            .absolute_x => self.getAbsoluteX(),
            .absolute_y => self.getAbsoluteY(),
            .indirect_x => self.getIndirectX(),
            .indirect_y => self.getIndirectY(),
            else => unreachable,
        };
        self.writeMemory(addr, value);
    }

    inline fn getZeroPage(self: *CPU) u16 {
        return @as(u16, self.fetchU8());
    }

    inline fn getZeroPageX(self: *CPU) u16 {
        return @as(u16, (self.fetchU8() + self.registers.x) & 0xFF);
    }

    inline fn getZeroPageY(self: *CPU) u16 {
        return @as(u16, (self.fetchU8() + self.registers.y) & 0xFF);
    }

    inline fn getAbsolute(self: *CPU) u16 {
        return self.fetchU16();
    }

    inline fn getAbsoluteX(self: *CPU) u16 {
        return self.fetchU16() + @as(u16, self.registers.x);
    }

    inline fn getAbsoluteY(self: *CPU) u16 {
        return self.fetchU16() + @as(u16, self.registers.y);
    }

    inline fn getIndirectX(self: *CPU) u16 {
        const base = (self.fetchU8() + self.registers.x) & 0xFF;
        return self.readU16ZP(@as(u8, base));
    }

    inline fn getIndirectY(self: *CPU) u16 {
        const base = self.readU16ZP(self.fetchU8());
        return base + @as(u16, self.registers.y);
    }

    inline fn updateZN(self: *CPU, value: u8) void {
        self.registers.flags.z = (value == 0);
        self.registers.flags.n = (value & 0x80) != 0;
    }

    inline fn readU16ZP(self: *CPU, addr: u8) u16 {
        const low = self.readMemory(@as(u16, addr));
        const high = self.readMemory(@as(u16, (addr + 1) & 0xFF));
        return @as(u16, low) | (@as(u16, high) << 8);
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
        const value = self.readFrom(addressing_mode);
        self.registers.a = value;
        self.updateZN(value);
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
        const value = self.readFrom(addressing_mode);
        self.compare(self.registers.a, value);
    }

    inline fn opLdy(self: *CPU, addressing_mode: Opcode.AddressingMode) void {
        const value = self.readFrom(addressing_mode);
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
        self.writeTo(addressing_mode, self.registers.a);
    }

    inline fn opStx(self: *CPU, addressing_mode: Opcode.AddressingMode) void {
        self.writeTo(addressing_mode, self.registers.x);
    }

    inline fn opSty(self: *CPU, addressing_mode: Opcode.AddressingMode) void {
        self.writeTo(addressing_mode, self.registers.y);
    }

    inline fn opLdx(self: *CPU, addressing_mode: Opcode.AddressingMode) void {
        const value = self.readFrom(addressing_mode);
        self.registers.x = value;
        self.updateZN(value);
    }

    inline fn opBit(self: *CPU, addressing_mode: Opcode.AddressingMode) void {
        const addr = switch (addressing_mode) {
            .zero_page => self.fetchU8(),
            .absolute => self.fetchU16(),
            else => unreachable,
        };
        const value = self.readMemory(addr);

        const result = self.registers.a & value;

        self.registers.flags.z = (result == 0);
        self.registers.flags.n = (value & 0b1000_0000) != 0;
        self.registers.flags.v = (value & 0b0100_0000) != 0;
    }
};
