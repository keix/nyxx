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
            (0b00100000) | // bit 5 always set
            (@as(u8, @intFromBool(self.v)) << 6) |
            (@as(u8, @intFromBool(self.n)) << 7);
    }

    pub fn fromByte(byte: u8) Flags {
        // Convert a byte representation back to flags
        return Flags{
            .c = (byte & 0x01) != 0, // Carry flag
            .z = (byte & 0x02) != 0, // Zero flag
            .i = (byte & 0x04) != 0, // Interrupt flag
            .d = (byte & 0x08) != 0, // Decimal flag is not used in NES
            .b = false, // Break flag is not used in NES
            .v = (byte & 0x40) != 0, // Overflow flag
            .n = (byte & 0x80) != 0, // Negative flag
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

const ShiftResult = struct {
    value: u8,
    carry: bool,
};

const ShiftOperation = enum {
    lsr, // Logical Shift Right
    asl, // Arithmetic Shift Left
    ror, // Rotate Right
    rol, // Rotate Left
};

pub const CPU = struct {
    registers: Registers,
    bus: *Bus,

    page_crossed: bool = false,
    branch_taken: bool = false,

    pub fn init(bus: *Bus) CPU {
        var cpu = CPU{
            .bus = bus,
            .registers = Registers{},
        };

        cpu.reset();
        return cpu;
    }

    fn reset(self: *CPU) void {
        self.registers.pc = self.bus.cartridge.getResetVector();
    }

    inline fn readMemory(self: *CPU, addr: u16) u8 {
        return self.bus.read(addr);
    }

    inline fn writeMemory(self: *CPU, addr: u16, data: u8) void {
        self.bus.write(addr, data);
    }

    pub fn step(self: *CPU) u8 {
        const instr = self.fetch();
        self.execute(instr);
        return self.calculateNextCycles(instr);
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
            .TXA => self.opTxa(),
            .TYA => self.opTya(),
            .TSX => self.opTsx(),
            .TXS => self.opTxs(),
            .INC => self.opInc(instr.addressing_mode),
            .DEC => self.opDec(instr.addressing_mode),
            .JMP => self.opJmp(instr.addressing_mode),
            .JSR => self.opJsr(),
            .RTS => self.opRts(),
            .RTI => self.opRti(),
            .BPL => self.opBpl(),
            .BMI => self.opBmi(),
            .BCC => self.opBcc(),
            .BCS => self.opBcs(),
            .BVC => self.opBvc(),
            .BVS => self.opBvs(),
            .ADC => self.opAdc(instr.addressing_mode),
            .SBC => self.opSbc(instr.addressing_mode),
            .AND => self.opAnd(instr.addressing_mode),
            .ORA => self.opOra(instr.addressing_mode),
            .EOR => self.opEor(instr.addressing_mode),
            .CPX => self.opCpx(instr.addressing_mode),
            .CPY => self.opCpy(instr.addressing_mode),
            .SED => self.opSed(),
            .CLD => self.opCld(),
            .CLV => self.opClv(),
            .NOP => self.opNop(),
            .LSR => self.opLsr(instr.addressing_mode),
            .ASL => self.opAsl(instr.addressing_mode),
            .ROL => self.opRol(instr.addressing_mode),
            .ROR => self.opRor(instr.addressing_mode),
            .BRK => self.opBrk(),
            // Add more opcodes as needed
            else => {
                std.debug.print("Unimplemented mnemonic: {}\n", .{instr.mnemonic});
            },
        }
    }

    inline fn fetch(self: *CPU) Opcode.Instruction {
        const opcode = self.fetchU8();

        self.page_crossed = false;
        self.branch_taken = false;

        std.debug.print("PC: 0x{X:0>4}, opcode: 0x{X:0>2}\n", .{ self.registers.pc, opcode });

        return Opcode.instruction_table[opcode];
    }

    inline fn fetchU8(self: *CPU) u8 {
        const value = self.readMemory(self.registers.pc);
        self.registers.pc +%= 1;
        return value;
    }

    inline fn fetchU16(self: *CPU) u16 {
        const low = self.fetchU8();
        const high = self.fetchU8();
        return (@as(u16, high) << 8) | @as(u16, low);
    }

    inline fn calculateNextCycles(self: *CPU, instr: Opcode.Instruction) u8 {
        var extra: u8 = 0;

        if (instr.may_page_cross) {
            if (self.branch_taken) {
                extra += 1;
                if (self.page_crossed) {
                    extra += 1;
                }
            } else if (self.page_crossed) {
                extra += 1;
            }
        }

        return instr.cycles + extra;
    }

    inline fn branch(self: *CPU, condition: bool, base: u16, target: u16) void {
        if (condition) {
            self.branch_taken = true;
            self.page_crossed = (base & 0xFF00) != (target & 0xFF00);
            self.registers.pc = target;
        } else {
            self.branch_taken = false;
            self.page_crossed = false;
        }
    }

    inline fn calculateBranchTarget(base: u16, offset: i8) u16 {
        return if (offset >= 0)
            base +% @as(u16, @intCast(offset))
        else
            base -% @as(u16, @intCast(-offset));
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

    inline fn performShiftOperation(self: *CPU, addressing_mode: Opcode.AddressingMode, operation: ShiftOperation) void {
        switch (addressing_mode) {
            .accumulator => {
                const result = self.shiftValue(self.registers.a, operation);
                self.registers.a = result.value;
                self.registers.flags.c = result.carry;
                self.updateZN(result.value);
            },
            else => {
                const addr = self.getAddress(addressing_mode);
                const value = self.readMemory(addr);

                const result = self.shiftValue(value, operation);

                self.writeMemory(addr, result.value);
                self.registers.flags.c = result.carry;
                self.updateZN(result.value);
            },
        }
    }

    inline fn shiftValue(self: *CPU, value: u8, operation: ShiftOperation) ShiftResult {
        var result: ShiftResult = undefined;

        switch (operation) {
            .lsr => {
                result.value = value >> 1;
                result.carry = (value & 0x01) != 0;
            },
            .asl => {
                result.value = value << 1;
                result.carry = (value & 0x80) != 0;
            },
            .rol => {
                const carry_in = @intFromBool(self.registers.flags.c); // 0 or 1
                result.value = (value << 1) | carry_in;
                result.carry = (value & 0x80) != 0;
            },
            .ror => {
                const carry_in = @as(u8, @intFromBool(self.registers.flags.c)) << 7; // 0x00 or 0x80
                result.value = (value >> 1) | carry_in;
                result.carry = (value & 0x01) != 0;
            },
        }

        return result;
    }

    inline fn getAddress(self: *CPU, mode: Opcode.AddressingMode) u16 {
        return switch (mode) {
            .zero_page => self.getZeroPage(),
            .zero_page_x => self.getZeroPageX(),
            .absolute => self.getAbsolute(),
            .absolute_x => self.getAbsoluteX(),
            else => unreachable,
        };
    }

    inline fn peekStack(self: *CPU, offset: u8) u8 {
        const addr = 0x0100 + @as(u16, self.registers.s) + @as(u16, offset);
        if (addr > 0x01FF) {
            @panic("Stack peek out of bounds");
        }
        return self.readMemory(addr);
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
        const base = self.fetchU16();
        const addr = base +% @as(u16, self.registers.x);
        self.page_crossed = (base & 0xFF00) != (addr & 0xFF00);
        return addr;
    }

    inline fn getAbsoluteY(self: *CPU) u16 {
        const base = self.fetchU16();
        const addr = base +% @as(u16, self.registers.y);
        self.page_crossed = (base & 0xFF00) != (addr & 0xFF00);
        return addr;
    }

    inline fn getIndirectX(self: *CPU) u16 {
        const base = (self.fetchU8() + self.registers.x) & 0xFF;
        return self.readU16ZP(@as(u8, base));
    }

    inline fn getIndirectY(self: *CPU) u16 {
        const base = self.readU16ZP(self.fetchU8());
        const addr = base +% @as(u16, self.registers.y);
        self.page_crossed = (base & 0xFF00) != (addr & 0xFF00);
        return addr;
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
        const base = self.registers.pc;
        const target = calculateBranchTarget(base, offset);
        self.branch(self.registers.flags.z, base, target);
    }

    inline fn opBne(self: *CPU) void {
        const offset = @as(i8, @bitCast(self.fetchU8()));
        const base = self.registers.pc;
        const target = calculateBranchTarget(base, offset);
        self.branch(!self.registers.flags.z, base, target);
    }

    inline fn opBpl(self: *CPU) void {
        const offset = @as(i8, @bitCast(self.fetchU8()));
        const base = self.registers.pc;
        const target = calculateBranchTarget(base, offset);
        self.branch(!self.registers.flags.n, base, target);
    }

    inline fn opBmi(self: *CPU) void {
        const offset = @as(i8, @bitCast(self.fetchU8()));
        const base = self.registers.pc;
        const target = calculateBranchTarget(base, offset);
        self.branch(self.registers.flags.n, base, target);
    }

    inline fn opBcc(self: *CPU) void {
        const offset = @as(i8, @bitCast(self.fetchU8()));
        const base = self.registers.pc;
        const target = calculateBranchTarget(base, offset);
        self.branch(!self.registers.flags.c, base, target);
    }

    inline fn opBcs(self: *CPU) void {
        const offset = @as(i8, @bitCast(self.fetchU8()));
        const base = self.registers.pc;
        const target = calculateBranchTarget(base, offset);
        self.branch(self.registers.flags.c, base, target);
    }

    inline fn opBvc(self: *CPU) void {
        const offset = @as(i8, @bitCast(self.fetchU8()));
        const base = self.registers.pc;
        const target = calculateBranchTarget(base, offset);
        self.branch(!self.registers.flags.v, base, target);
    }

    inline fn opBvs(self: *CPU) void {
        const offset = @as(i8, @bitCast(self.fetchU8()));
        const base = self.registers.pc;
        const target = calculateBranchTarget(base, offset);
        self.branch(self.registers.flags.v, base, target);
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

    inline fn opInc(self: *CPU, addressing_mode: Opcode.AddressingMode) void {
        const addr = self.getAddress(addressing_mode);
        const value = self.readMemory(addr) +% 1;

        self.writeMemory(addr, value);
        self.updateZN(value);
    }

    inline fn opDec(self: *CPU, addressing_mode: Opcode.AddressingMode) void {
        const addr = self.getAddress(addressing_mode);
        const value = self.readMemory(addr) -% 1;

        self.writeMemory(addr, value);
        self.updateZN(value);
    }

    inline fn opTxa(self: *CPU) void {
        self.registers.a = self.registers.x;
        self.updateZN(self.registers.a);
    }

    inline fn opTya(self: *CPU) void {
        self.registers.a = self.registers.y;
        self.updateZN(self.registers.a);
    }

    inline fn opTsx(self: *CPU) void {
        self.registers.x = self.registers.s;
        self.updateZN(self.registers.x);
    }

    inline fn opTxs(self: *CPU) void {
        self.registers.s = self.registers.x;
    }

    inline fn opBit(self: *CPU, addressing_mode: Opcode.AddressingMode) void {
        const value = self.readFrom(addressing_mode);
        const result = self.registers.a & value;

        self.registers.flags.z = (result == 0);
        self.registers.flags.n = (value & 0b1000_0000) != 0;
        self.registers.flags.v = (value & 0b0100_0000) != 0;
    }

    inline fn opJmp(self: *CPU, addressing_mode: Opcode.AddressingMode) void {
        self.registers.pc = switch (addressing_mode) {
            .absolute => self.getAbsolute(),
            .indirect => blk: {
                const ptr = self.fetchU16();

                // 6502 indirect bug: if LSB == 0xFF, wrap to page start for MSB
                const lsb = self.readMemory(ptr);
                const msb = self.readMemory((ptr & 0xFF00) | ((ptr + 1) & 0x00FF));

                break :blk (@as(u16, msb) << 8) | lsb;
            },
            else => unreachable,
        };
    }

    inline fn opJsr(self: *CPU) void {
        const addr = self.fetchU16();
        const return_addr = self.registers.pc - 1;

        self.push(@as(u8, @truncate(return_addr >> 8)));
        self.push(@as(u8, @truncate(return_addr & 0xFF)));

        self.registers.pc = addr;
    }

    inline fn opRts(self: *CPU) void {
        const low = self.pop();
        const high = self.pop();
        const addr = (@as(u16, high) << 8) | @as(u16, low);
        self.registers.pc = addr + 1;
    }

    inline fn opRti(self: *CPU) void {
        const flags = self.pop();
        self.registers.flags = Flags.fromByte(flags);

        const low = self.pop();
        const high = self.pop();
        self.registers.pc = (@as(u16, high) << 8) | @as(u16, low);
    }

    inline fn opAdc(self: *CPU, mode: Opcode.AddressingMode) void {
        const value = self.readFrom(mode);
        const a = self.registers.a;
        const c = @as(u8, @intFromBool(self.registers.flags.c));

        const sum = @as(u16, a) + @as(u16, value) + @as(u16, c);
        const result = @as(u8, @truncate(sum));

        self.registers.flags.c = sum > 0xFF;
        self.registers.flags.z = result == 0;
        self.registers.flags.n = (result & 0x80) != 0;
        self.registers.flags.v = ((~(a ^ value)) & (a ^ result) & 0x80) != 0;

        self.registers.a = result;
    }

    inline fn opSbc(self: *CPU, addressing_mode: Opcode.AddressingMode) void {
        const original_value = self.readFrom(addressing_mode);
        const value = original_value ^ 0xFF;
        const carry = @as(u8, @intFromBool(self.registers.flags.c));
        const result = self.registers.a +% value + carry;

        self.registers.flags.c = (@as(u16, self.registers.a) + @as(u16, value) + carry) > 0xFF;
        self.registers.flags.v = ((self.registers.a ^ result) & (original_value ^ result) & 0x80) != 0;

        self.registers.a = result;
        self.updateZN(result);
    }

    inline fn opAnd(self: *CPU, addressing_mode: Opcode.AddressingMode) void {
        const value = self.readFrom(addressing_mode);
        self.registers.a &= value;
        self.updateZN(self.registers.a);
    }

    inline fn opOra(self: *CPU, addressing_mode: Opcode.AddressingMode) void {
        const value = self.readFrom(addressing_mode);
        self.registers.a |= value;
        self.updateZN(self.registers.a);
    }

    inline fn opEor(self: *CPU, addressing_mode: Opcode.AddressingMode) void {
        const value = self.readFrom(addressing_mode);
        self.registers.a ^= value;
        self.updateZN(self.registers.a);
    }

    inline fn opCpx(self: *CPU, addressing_mode: Opcode.AddressingMode) void {
        const value = self.readFrom(addressing_mode);
        self.compare(self.registers.x, value);
    }

    inline fn opCpy(self: *CPU, addressing_mode: Opcode.AddressingMode) void {
        const value = self.readFrom(addressing_mode);
        self.compare(self.registers.y, value);
    }

    inline fn opSed(self: *CPU) void {
        self.registers.flags.d = true;
    }

    inline fn opCld(self: *CPU) void {
        self.registers.flags.d = false;
    }

    inline fn opClv(self: *CPU) void {
        self.registers.flags.v = false;
    }

    inline fn opNop(self: *CPU) void {
        // Do nothing - that's the point!
        _ = self;
    }

    inline fn opLsr(self: *CPU, addressing_mode: Opcode.AddressingMode) void {
        self.performShiftOperation(addressing_mode, .lsr);
    }

    inline fn opAsl(self: *CPU, addressing_mode: Opcode.AddressingMode) void {
        self.performShiftOperation(addressing_mode, .asl);
    }

    inline fn opRol(self: *CPU, addressing_mode: Opcode.AddressingMode) void {
        self.performShiftOperation(addressing_mode, .rol);
    }

    inline fn opRor(self: *CPU, addressing_mode: Opcode.AddressingMode) void {
        self.performShiftOperation(addressing_mode, .ror);
    }

    inline fn opBrk(self: *CPU) void {
        const return_addr = self.registers.pc + 1;
        self.push(@as(u8, @truncate(return_addr >> 8)));
        self.push(@as(u8, @truncate(return_addr & 0xFF)));

        const flags = self.registers.flags.toByte() | 0b00110000;
        self.push(flags);

        self.registers.flags.i = true;

        const low = self.readMemory(0xFFFE);
        const high = self.readMemory(0xFFFF);
        self.registers.pc = (@as(u16, high) << 8) | low;
    }
};
