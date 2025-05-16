const std = @import("std");
const MEMORY_SIZE: usize = 65536;

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
    memory: [MEMORY_SIZE]u8 = undefined,

    pub fn readMemory(self: *CPU, addr: u16) u8 {
        return self.memory[addr];
    }

    pub fn writeMemory(self: *CPU, addr: u16, data: u8) void {
        self.memory[addr] = data;
    }

    pub fn step(self: *CPU) void {
        const opcode = self.readMemory(self.registers.pc);
        self.registers.pc += 1;

        switch (opcode) {
            0xA9 => {
                const value = self.readMemory(self.registers.pc);
                self.registers.pc += 1;
                self.registers.a = value;

                self.registers.flags.z = (self.registers.a == 0);
                self.registers.flags.n = (self.registers.a & 0x80) != 0;
            },
            else => {
                // std.debug.print("Undefined opecode: 0x{X:0>2}\n", .{opcode});
            },
        }
    }
};

pub fn main() !void {
    var cpu = CPU{};

    cpu.memory[0x0000] = 0xA9; // LDA #$42
    cpu.memory[0x0001] = 0x42;

    cpu.step();

    std.debug.print("A: 0x{X:0>2}\n", .{cpu.registers.a});
}
