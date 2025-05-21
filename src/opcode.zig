// opcode.zig

pub const Mnemonic = enum {
    ADC,
    AND,
    ASL,
    BCC,
    BCS,
    BEQ,
    BIT,
    BMI,
    BNE,
    BPL,
    BRK,
    BVC,
    BVS,
    CLC,
    CLD,
    CLI,
    CLV,
    CMP,
    CPX,
    CPY,
    DEC,
    DEX,
    DEY,
    EOR,
    INC,
    INX,
    INY,
    JMP,
    JSR,
    LDA,
    LDX,
    LDY,
    LSR,
    NOP,
    ORA,
    PHA,
    PHP,
    PLA,
    PLP,
    ROL,
    ROR,
    RTI,
    RTS,
    SBC,
    SEC,
    SED,
    SEI,
    STA,
    STX,
    STY,
    TAX,
    TAY,
    TSX,
    TXA,
    TXS,
    TYA,
    // Unofficial opcodes can be added later
    INVALID,
};

pub const AddressingMode = enum {
    implied,
    accumulator,
    immediate,
    zero_page,
    zero_page_x,
    zero_page_y,
    relative,
    absolute,
    absolute_x,
    absolute_y,
    indirect,
    indirect_x,
    indirect_y,
};

pub const Instruction = struct {
    mnemonic: Mnemonic,
    addressing_mode: AddressingMode,
    cycles: u8,
    may_page_cross: bool = false,
};

pub const instruction_table = blk: {
    const invalid_instruction = Instruction{
        .mnemonic = Mnemonic.INVALID,
        .addressing_mode = AddressingMode.implied,
        .cycles = 0,
        .may_page_cross = false,
    };

    var table: [256]Instruction = .{invalid_instruction} ** 256;

    table[0xA9] = .{ .mnemonic = .LDA, .addressing_mode = .immediate, .cycles = 2 };
    table[0xA5] = .{ .mnemonic = .LDA, .addressing_mode = .zero_page, .cycles = 3 };
    table[0xB5] = .{ .mnemonic = .LDA, .addressing_mode = .zero_page_x, .cycles = 4 };
    table[0xAD] = .{ .mnemonic = .LDA, .addressing_mode = .absolute, .cycles = 4 };
    table[0xBD] = .{ .mnemonic = .LDA, .addressing_mode = .absolute_x, .cycles = 4, .may_page_cross = true }; // +1 if page crossed
    table[0xB9] = .{ .mnemonic = .LDA, .addressing_mode = .absolute_y, .cycles = 4 }; // +1 if page crossed
    table[0xA1] = .{ .mnemonic = .LDA, .addressing_mode = .indirect_x, .cycles = 6 };
    table[0xB1] = .{ .mnemonic = .LDA, .addressing_mode = .indirect_y, .cycles = 5 }; // +1 if page crossed

    table[0xA2] = .{ .mnemonic = .LDX, .addressing_mode = .immediate, .cycles = 2 };
    table[0xA6] = .{ .mnemonic = .LDX, .addressing_mode = .zero_page, .cycles = 3 };
    table[0xB6] = .{ .mnemonic = .LDX, .addressing_mode = .zero_page_y, .cycles = 4 };
    table[0xAE] = .{ .mnemonic = .LDX, .addressing_mode = .absolute, .cycles = 4 };
    table[0xBE] = .{ .mnemonic = .LDX, .addressing_mode = .absolute_y, .cycles = 4 }; // +1 if page crossed

    table[0xA0] = .{ .mnemonic = .LDY, .addressing_mode = .immediate, .cycles = 2 };
    table[0xA4] = .{ .mnemonic = .LDY, .addressing_mode = .zero_page, .cycles = 3 };
    table[0xB4] = .{ .mnemonic = .LDY, .addressing_mode = .zero_page_x, .cycles = 4 };
    table[0xAC] = .{ .mnemonic = .LDY, .addressing_mode = .absolute, .cycles = 4 };
    table[0xBC] = .{ .mnemonic = .LDY, .addressing_mode = .absolute_x, .cycles = 4 }; // +1 if page crossed

    table[0xC9] = .{ .mnemonic = .CMP, .addressing_mode = .immediate, .cycles = 2 };
    table[0xC5] = .{ .mnemonic = .CMP, .addressing_mode = .zero_page, .cycles = 3 };
    table[0xD5] = .{ .mnemonic = .CMP, .addressing_mode = .zero_page_x, .cycles = 4 };
    table[0xCD] = .{ .mnemonic = .CMP, .addressing_mode = .absolute, .cycles = 4 };
    table[0xDD] = .{ .mnemonic = .CMP, .addressing_mode = .absolute_x, .cycles = 4 }; // +1 if page crossed
    table[0xD9] = .{ .mnemonic = .CMP, .addressing_mode = .absolute_y, .cycles = 4 }; // +1 if page crossed
    table[0xC1] = .{ .mnemonic = .CMP, .addressing_mode = .indirect_x, .cycles = 6 };
    table[0xD1] = .{ .mnemonic = .CMP, .addressing_mode = .indirect_y, .cycles = 5 }; // +1 if page crossed

    table[0x85] = .{ .mnemonic = .STA, .addressing_mode = .zero_page, .cycles = 3 };
    table[0x95] = .{ .mnemonic = .STA, .addressing_mode = .zero_page_x, .cycles = 4 };
    table[0x8D] = .{ .mnemonic = .STA, .addressing_mode = .absolute, .cycles = 4 };
    table[0x9D] = .{ .mnemonic = .STA, .addressing_mode = .absolute_x, .cycles = 5 };
    table[0x99] = .{ .mnemonic = .STA, .addressing_mode = .absolute_y, .cycles = 5 };
    table[0x81] = .{ .mnemonic = .STA, .addressing_mode = .indirect_x, .cycles = 6 };
    table[0x91] = .{ .mnemonic = .STA, .addressing_mode = .indirect_y, .cycles = 6 };

    table[0x86] = .{ .mnemonic = .STX, .addressing_mode = .zero_page, .cycles = 3 };
    table[0x96] = .{ .mnemonic = .STX, .addressing_mode = .zero_page_x, .cycles = 4 };
    table[0x8E] = .{ .mnemonic = .STX, .addressing_mode = .absolute, .cycles = 4 };
    table[0x9E] = .{ .mnemonic = .STX, .addressing_mode = .absolute_x, .cycles = 5 };

    table[0x84] = .{ .mnemonic = .STY, .addressing_mode = .zero_page, .cycles = 3 };
    table[0x94] = .{ .mnemonic = .STY, .addressing_mode = .zero_page_x, .cycles = 4 };
    table[0x8C] = .{ .mnemonic = .STY, .addressing_mode = .absolute, .cycles = 4 };

    table[0xAA] = .{ .mnemonic = .TAX, .addressing_mode = .implied, .cycles = 2 };
    table[0xA8] = .{ .mnemonic = .TAY, .addressing_mode = .implied, .cycles = 2 };

    table[0xE8] = .{ .mnemonic = .INX, .addressing_mode = .implied, .cycles = 2 };
    table[0xC8] = .{ .mnemonic = .INY, .addressing_mode = .implied, .cycles = 2 };

    table[0xCA] = .{ .mnemonic = .DEX, .addressing_mode = .implied, .cycles = 2 };
    table[0x88] = .{ .mnemonic = .DEY, .addressing_mode = .implied, .cycles = 2 };

    table[0xF0] = .{ .mnemonic = .BEQ, .addressing_mode = .relative, .cycles = 2, .may_page_cross = true };
    table[0xD0] = .{ .mnemonic = .BNE, .addressing_mode = .relative, .cycles = 2, .may_page_cross = true };
    table[0x10] = .{ .mnemonic = .BPL, .addressing_mode = .relative, .cycles = 2, .may_page_cross = true };
    table[0x30] = .{ .mnemonic = .BMI, .addressing_mode = .relative, .cycles = 2, .may_page_cross = true };
    table[0x90] = .{ .mnemonic = .BCC, .addressing_mode = .relative, .cycles = 2, .may_page_cross = true };
    table[0xB0] = .{ .mnemonic = .BCS, .addressing_mode = .relative, .cycles = 2, .may_page_cross = true };
    table[0x50] = .{ .mnemonic = .BVC, .addressing_mode = .relative, .cycles = 2, .may_page_cross = true };
    table[0x70] = .{ .mnemonic = .BVS, .addressing_mode = .relative, .cycles = 2, .may_page_cross = true };

    table[0x48] = .{ .mnemonic = .PHA, .addressing_mode = .implied, .cycles = 3 };
    table[0x68] = .{ .mnemonic = .PLA, .addressing_mode = .implied, .cycles = 4 };
    table[0x08] = .{ .mnemonic = .PHP, .addressing_mode = .implied, .cycles = 3 };
    table[0x28] = .{ .mnemonic = .PLP, .addressing_mode = .implied, .cycles = 4 };

    table[0x38] = .{ .mnemonic = .SEC, .addressing_mode = .implied, .cycles = 2 };
    table[0x78] = .{ .mnemonic = .SEI, .addressing_mode = .implied, .cycles = 2 };

    table[0x18] = .{ .mnemonic = .CLC, .addressing_mode = .implied, .cycles = 2 };
    table[0x58] = .{ .mnemonic = .CLI, .addressing_mode = .implied, .cycles = 2 };

    table[0xE6] = .{ .mnemonic = .INC, .addressing_mode = .zero_page, .cycles = 5 };
    table[0xF6] = .{ .mnemonic = .INC, .addressing_mode = .zero_page_x, .cycles = 6 };
    table[0xEE] = .{ .mnemonic = .INC, .addressing_mode = .absolute, .cycles = 6 };
    table[0xFE] = .{ .mnemonic = .INC, .addressing_mode = .absolute_x, .cycles = 7 };

    table[0xC6] = .{ .mnemonic = .DEC, .addressing_mode = .zero_page, .cycles = 5 };
    table[0xD6] = .{ .mnemonic = .DEC, .addressing_mode = .zero_page_x, .cycles = 6 };
    table[0xCE] = .{ .mnemonic = .DEC, .addressing_mode = .absolute, .cycles = 6 };
    table[0xDE] = .{ .mnemonic = .DEC, .addressing_mode = .absolute_x, .cycles = 7 };

    table[0xBA] = .{ .mnemonic = .TSX, .addressing_mode = .implied, .cycles = 2 };
    table[0x9A] = .{ .mnemonic = .TXS, .addressing_mode = .implied, .cycles = 2 };

    table[0x24] = .{ .mnemonic = .BIT, .addressing_mode = .zero_page, .cycles = 3 };
    table[0x2C] = .{ .mnemonic = .BIT, .addressing_mode = .absolute, .cycles = 4 };

    table[0x8A] = .{ .mnemonic = .TXA, .addressing_mode = .implied, .cycles = 2 };
    table[0x98] = .{ .mnemonic = .TYA, .addressing_mode = .implied, .cycles = 2 };

    table[0x4C] = .{ .mnemonic = .JMP, .addressing_mode = .absolute, .cycles = 3 };
    table[0x6C] = .{ .mnemonic = .JMP, .addressing_mode = .indirect, .cycles = 5 };

    table[0x20] = .{ .mnemonic = .JSR, .addressing_mode = .absolute, .cycles = 6 };
    table[0x60] = .{ .mnemonic = .RTS, .addressing_mode = .implied, .cycles = 6 };
    table[0x40] = .{ .mnemonic = .RTI, .addressing_mode = .implied, .cycles = 6 };

    break :blk table;
};
