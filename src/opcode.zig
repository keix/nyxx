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
    // Unofficial opcodes
    SLO,
    SRE,
    RLA,
    RRA,
    DCP,
    ISB,
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

    // Fill the instruction table with valid opcodes
    table[0xA9] = .{ .mnemonic = .LDA, .addressing_mode = .immediate, .cycles = 2 };
    table[0xA5] = .{ .mnemonic = .LDA, .addressing_mode = .zero_page, .cycles = 3 };
    table[0xB5] = .{ .mnemonic = .LDA, .addressing_mode = .zero_page_x, .cycles = 4 };
    table[0xAD] = .{ .mnemonic = .LDA, .addressing_mode = .absolute, .cycles = 4 };
    table[0xBD] = .{ .mnemonic = .LDA, .addressing_mode = .absolute_x, .cycles = 4, .may_page_cross = true };
    table[0xB9] = .{ .mnemonic = .LDA, .addressing_mode = .absolute_y, .cycles = 4, .may_page_cross = true };
    table[0xA1] = .{ .mnemonic = .LDA, .addressing_mode = .indirect_x, .cycles = 6 };
    table[0xB1] = .{ .mnemonic = .LDA, .addressing_mode = .indirect_y, .cycles = 5, .may_page_cross = true };

    table[0xA2] = .{ .mnemonic = .LDX, .addressing_mode = .immediate, .cycles = 2 };
    table[0xA6] = .{ .mnemonic = .LDX, .addressing_mode = .zero_page, .cycles = 3 };
    table[0xB6] = .{ .mnemonic = .LDX, .addressing_mode = .zero_page_y, .cycles = 4 };
    table[0xAE] = .{ .mnemonic = .LDX, .addressing_mode = .absolute, .cycles = 4 };
    table[0xBE] = .{ .mnemonic = .LDX, .addressing_mode = .absolute_y, .cycles = 4, .may_page_cross = true };

    table[0xA0] = .{ .mnemonic = .LDY, .addressing_mode = .immediate, .cycles = 2 };
    table[0xA4] = .{ .mnemonic = .LDY, .addressing_mode = .zero_page, .cycles = 3 };
    table[0xB4] = .{ .mnemonic = .LDY, .addressing_mode = .zero_page_x, .cycles = 4 };
    table[0xAC] = .{ .mnemonic = .LDY, .addressing_mode = .absolute, .cycles = 4 };
    table[0xBC] = .{ .mnemonic = .LDY, .addressing_mode = .absolute_x, .cycles = 4, .may_page_cross = true };

    table[0xC9] = .{ .mnemonic = .CMP, .addressing_mode = .immediate, .cycles = 2 };
    table[0xC5] = .{ .mnemonic = .CMP, .addressing_mode = .zero_page, .cycles = 3 };
    table[0xD5] = .{ .mnemonic = .CMP, .addressing_mode = .zero_page_x, .cycles = 4 };
    table[0xCD] = .{ .mnemonic = .CMP, .addressing_mode = .absolute, .cycles = 4 };
    table[0xDD] = .{ .mnemonic = .CMP, .addressing_mode = .absolute_x, .cycles = 4, .may_page_cross = true };
    table[0xD9] = .{ .mnemonic = .CMP, .addressing_mode = .absolute_y, .cycles = 4, .may_page_cross = true };
    table[0xC1] = .{ .mnemonic = .CMP, .addressing_mode = .indirect_x, .cycles = 6 };
    table[0xD1] = .{ .mnemonic = .CMP, .addressing_mode = .indirect_y, .cycles = 5, .may_page_cross = true };

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

    table[0x69] = .{ .mnemonic = .ADC, .addressing_mode = .immediate, .cycles = 2 };
    table[0x65] = .{ .mnemonic = .ADC, .addressing_mode = .zero_page, .cycles = 3 };
    table[0x75] = .{ .mnemonic = .ADC, .addressing_mode = .zero_page_x, .cycles = 4 };
    table[0x6D] = .{ .mnemonic = .ADC, .addressing_mode = .absolute, .cycles = 4 };
    table[0x7D] = .{ .mnemonic = .ADC, .addressing_mode = .absolute_x, .cycles = 4, .may_page_cross = true };
    table[0x79] = .{ .mnemonic = .ADC, .addressing_mode = .absolute_y, .cycles = 4, .may_page_cross = true };
    table[0x61] = .{ .mnemonic = .ADC, .addressing_mode = .indirect_x, .cycles = 6 };
    table[0x71] = .{ .mnemonic = .ADC, .addressing_mode = .indirect_y, .cycles = 5, .may_page_cross = true };

    table[0xE9] = .{ .mnemonic = .SBC, .addressing_mode = .immediate, .cycles = 2 };
    table[0xE5] = .{ .mnemonic = .SBC, .addressing_mode = .zero_page, .cycles = 3 };
    table[0xF5] = .{ .mnemonic = .SBC, .addressing_mode = .zero_page_x, .cycles = 4 };
    table[0xED] = .{ .mnemonic = .SBC, .addressing_mode = .absolute, .cycles = 4 };
    table[0xFD] = .{ .mnemonic = .SBC, .addressing_mode = .absolute_x, .cycles = 4, .may_page_cross = true };
    table[0xF9] = .{ .mnemonic = .SBC, .addressing_mode = .absolute_y, .cycles = 4, .may_page_cross = true };
    table[0xE1] = .{ .mnemonic = .SBC, .addressing_mode = .indirect_x, .cycles = 6 };
    table[0xF1] = .{ .mnemonic = .SBC, .addressing_mode = .indirect_y, .cycles = 5, .may_page_cross = true };

    table[0x29] = .{ .mnemonic = .AND, .addressing_mode = .immediate, .cycles = 2 };
    table[0x25] = .{ .mnemonic = .AND, .addressing_mode = .zero_page, .cycles = 3 };
    table[0x35] = .{ .mnemonic = .AND, .addressing_mode = .zero_page_x, .cycles = 4 };
    table[0x2D] = .{ .mnemonic = .AND, .addressing_mode = .absolute, .cycles = 4 };
    table[0x3D] = .{ .mnemonic = .AND, .addressing_mode = .absolute_x, .cycles = 4, .may_page_cross = true };
    table[0x39] = .{ .mnemonic = .AND, .addressing_mode = .absolute_y, .cycles = 4, .may_page_cross = true };
    table[0x21] = .{ .mnemonic = .AND, .addressing_mode = .indirect_x, .cycles = 6 };
    table[0x31] = .{ .mnemonic = .AND, .addressing_mode = .indirect_y, .cycles = 5, .may_page_cross = true };

    table[0x09] = .{ .mnemonic = .ORA, .addressing_mode = .immediate, .cycles = 2 };
    table[0x05] = .{ .mnemonic = .ORA, .addressing_mode = .zero_page, .cycles = 3 };
    table[0x15] = .{ .mnemonic = .ORA, .addressing_mode = .zero_page_x, .cycles = 4 };
    table[0x0D] = .{ .mnemonic = .ORA, .addressing_mode = .absolute, .cycles = 4 };
    table[0x1D] = .{ .mnemonic = .ORA, .addressing_mode = .absolute_x, .cycles = 4, .may_page_cross = true };
    table[0x19] = .{ .mnemonic = .ORA, .addressing_mode = .absolute_y, .cycles = 4, .may_page_cross = true };
    table[0x01] = .{ .mnemonic = .ORA, .addressing_mode = .indirect_x, .cycles = 6 };
    table[0x11] = .{ .mnemonic = .ORA, .addressing_mode = .indirect_y, .cycles = 5, .may_page_cross = true };

    table[0x49] = .{ .mnemonic = .EOR, .addressing_mode = .immediate, .cycles = 2 };
    table[0x45] = .{ .mnemonic = .EOR, .addressing_mode = .zero_page, .cycles = 3 };
    table[0x55] = .{ .mnemonic = .EOR, .addressing_mode = .zero_page_x, .cycles = 4 };
    table[0x4D] = .{ .mnemonic = .EOR, .addressing_mode = .absolute, .cycles = 4 };
    table[0x5D] = .{ .mnemonic = .EOR, .addressing_mode = .absolute_x, .cycles = 4, .may_page_cross = true };
    table[0x59] = .{ .mnemonic = .EOR, .addressing_mode = .absolute_y, .cycles = 4, .may_page_cross = true };
    table[0x41] = .{ .mnemonic = .EOR, .addressing_mode = .indirect_x, .cycles = 6 };
    table[0x51] = .{ .mnemonic = .EOR, .addressing_mode = .indirect_y, .cycles = 5, .may_page_cross = true };

    table[0xE0] = .{ .mnemonic = .CPX, .addressing_mode = .immediate, .cycles = 2 };
    table[0xE4] = .{ .mnemonic = .CPX, .addressing_mode = .zero_page, .cycles = 3 };
    table[0xEC] = .{ .mnemonic = .CPX, .addressing_mode = .absolute, .cycles = 4 };

    table[0xC0] = .{ .mnemonic = .CPY, .addressing_mode = .immediate, .cycles = 2 };
    table[0xC4] = .{ .mnemonic = .CPY, .addressing_mode = .zero_page, .cycles = 3 };
    table[0xCC] = .{ .mnemonic = .CPY, .addressing_mode = .absolute, .cycles = 4 };

    table[0xF8] = .{ .mnemonic = .SED, .addressing_mode = .implied, .cycles = 2 };
    table[0xD8] = .{ .mnemonic = .CLD, .addressing_mode = .implied, .cycles = 2 };
    table[0xB8] = .{ .mnemonic = .CLV, .addressing_mode = .implied, .cycles = 2 };

    table[0x4A] = .{ .mnemonic = .LSR, .addressing_mode = .accumulator, .cycles = 2 };
    table[0x46] = .{ .mnemonic = .LSR, .addressing_mode = .zero_page, .cycles = 5 };
    table[0x56] = .{ .mnemonic = .LSR, .addressing_mode = .zero_page_x, .cycles = 6 };
    table[0x4E] = .{ .mnemonic = .LSR, .addressing_mode = .absolute, .cycles = 6 };
    table[0x5E] = .{ .mnemonic = .LSR, .addressing_mode = .absolute_x, .cycles = 7 };

    table[0x0A] = .{ .mnemonic = .ASL, .addressing_mode = .accumulator, .cycles = 2 };
    table[0x06] = .{ .mnemonic = .ASL, .addressing_mode = .zero_page, .cycles = 5 };
    table[0x16] = .{ .mnemonic = .ASL, .addressing_mode = .zero_page_x, .cycles = 6 };
    table[0x0E] = .{ .mnemonic = .ASL, .addressing_mode = .absolute, .cycles = 6 };
    table[0x1E] = .{ .mnemonic = .ASL, .addressing_mode = .absolute_x, .cycles = 7 };

    table[0x2A] = .{ .mnemonic = .ROL, .addressing_mode = .accumulator, .cycles = 2 };
    table[0x26] = .{ .mnemonic = .ROL, .addressing_mode = .zero_page, .cycles = 5 };
    table[0x36] = .{ .mnemonic = .ROL, .addressing_mode = .zero_page_x, .cycles = 6 };
    table[0x2E] = .{ .mnemonic = .ROL, .addressing_mode = .absolute, .cycles = 6 };
    table[0x3E] = .{ .mnemonic = .ROL, .addressing_mode = .absolute_x, .cycles = 7 };

    table[0x6A] = .{ .mnemonic = .ROR, .addressing_mode = .accumulator, .cycles = 2 };
    table[0x66] = .{ .mnemonic = .ROR, .addressing_mode = .zero_page, .cycles = 5 };
    table[0x76] = .{ .mnemonic = .ROR, .addressing_mode = .zero_page_x, .cycles = 6 };
    table[0x6E] = .{ .mnemonic = .ROR, .addressing_mode = .absolute, .cycles = 6 };
    table[0x7E] = .{ .mnemonic = .ROR, .addressing_mode = .absolute_x, .cycles = 7 };

    table[0x00] = .{ .mnemonic = .BRK, .addressing_mode = .implied, .cycles = 7 };
    table[0xEA] = .{ .mnemonic = .NOP, .addressing_mode = .implied, .cycles = 2 };

    // Unofficial opcodes
    table[0x0F] = .{ .mnemonic = .SLO, .addressing_mode = .absolute, .cycles = 6 };
    table[0x1F] = .{ .mnemonic = .SLO, .addressing_mode = .absolute_x, .cycles = 7 };
    table[0x1B] = .{ .mnemonic = .SLO, .addressing_mode = .absolute_y, .cycles = 7 };
    table[0x07] = .{ .mnemonic = .SLO, .addressing_mode = .zero_page, .cycles = 5 };
    table[0x17] = .{ .mnemonic = .SLO, .addressing_mode = .zero_page_x, .cycles = 6 };
    table[0x03] = .{ .mnemonic = .SLO, .addressing_mode = .indirect_x, .cycles = 8 };
    table[0x13] = .{ .mnemonic = .SLO, .addressing_mode = .indirect_y, .cycles = 8 };

    table[0x47] = .{ .mnemonic = .SRE, .addressing_mode = .zero_page, .cycles = 5 };
    table[0x57] = .{ .mnemonic = .SRE, .addressing_mode = .zero_page_x, .cycles = 6 };
    table[0x4F] = .{ .mnemonic = .SRE, .addressing_mode = .absolute, .cycles = 6 };
    table[0x5F] = .{ .mnemonic = .SRE, .addressing_mode = .absolute_x, .cycles = 7 };
    table[0x5B] = .{ .mnemonic = .SRE, .addressing_mode = .absolute_y, .cycles = 7 };
    table[0x43] = .{ .mnemonic = .SRE, .addressing_mode = .indirect_x, .cycles = 8 };
    table[0x53] = .{ .mnemonic = .SRE, .addressing_mode = .indirect_y, .cycles = 8 };

    table[0x27] = .{ .mnemonic = .RLA, .addressing_mode = .zero_page, .cycles = 5 };
    table[0x37] = .{ .mnemonic = .RLA, .addressing_mode = .zero_page_x, .cycles = 6 };
    table[0x2F] = .{ .mnemonic = .RLA, .addressing_mode = .absolute, .cycles = 6 };
    table[0x3F] = .{ .mnemonic = .RLA, .addressing_mode = .absolute_x, .cycles = 7 };
    table[0x3B] = .{ .mnemonic = .RLA, .addressing_mode = .absolute_y, .cycles = 7 };
    table[0x23] = .{ .mnemonic = .RLA, .addressing_mode = .indirect_x, .cycles = 8 };
    table[0x33] = .{ .mnemonic = .RLA, .addressing_mode = .indirect_y, .cycles = 8 };

    table[0x67] = .{ .mnemonic = .RRA, .addressing_mode = .zero_page, .cycles = 5 };
    table[0x77] = .{ .mnemonic = .RRA, .addressing_mode = .zero_page_x, .cycles = 6 };
    table[0x6F] = .{ .mnemonic = .RRA, .addressing_mode = .absolute, .cycles = 6 };
    table[0x7F] = .{ .mnemonic = .RRA, .addressing_mode = .absolute_x, .cycles = 7 };
    table[0x7B] = .{ .mnemonic = .RRA, .addressing_mode = .absolute_y, .cycles = 7 };
    table[0x63] = .{ .mnemonic = .RRA, .addressing_mode = .indirect_x, .cycles = 8 };
    table[0x73] = .{ .mnemonic = .RRA, .addressing_mode = .indirect_y, .cycles = 8 };

    table[0xC7] = .{ .mnemonic = .DCP, .addressing_mode = .zero_page, .cycles = 5 };
    table[0xD7] = .{ .mnemonic = .DCP, .addressing_mode = .zero_page_x, .cycles = 6 };
    table[0xCF] = .{ .mnemonic = .DCP, .addressing_mode = .absolute, .cycles = 6 };
    table[0xDF] = .{ .mnemonic = .DCP, .addressing_mode = .absolute_x, .cycles = 7 };
    table[0xDB] = .{ .mnemonic = .DCP, .addressing_mode = .absolute_y, .cycles = 7 };
    table[0xC3] = .{ .mnemonic = .DCP, .addressing_mode = .indirect_x, .cycles = 8 };
    table[0xD3] = .{ .mnemonic = .DCP, .addressing_mode = .indirect_y, .cycles = 8 };

    table[0xE7] = .{ .mnemonic = .ISB, .addressing_mode = .zero_page, .cycles = 5 };
    table[0xF7] = .{ .mnemonic = .ISB, .addressing_mode = .zero_page_x, .cycles = 6 };
    table[0xEF] = .{ .mnemonic = .ISB, .addressing_mode = .absolute, .cycles = 6 };
    table[0xFF] = .{ .mnemonic = .ISB, .addressing_mode = .absolute_x, .cycles = 7 };
    table[0xFB] = .{ .mnemonic = .ISB, .addressing_mode = .absolute_y, .cycles = 7 };
    table[0xE3] = .{ .mnemonic = .ISB, .addressing_mode = .indirect_x, .cycles = 8 };
    table[0xF3] = .{ .mnemonic = .ISB, .addressing_mode = .indirect_y, .cycles = 8 };

    break :blk table;
};
