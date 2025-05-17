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
    // exec: fn(*CPU) void — optional for function dispatch
};

pub const instruction_table = blk: {
    const invalid_instruction = Instruction{
        .mnemonic = Mnemonic.INVALID,
        .addressing_mode = AddressingMode.implied,
        .cycles = 0,
    };

    var table: [256]Instruction = .{invalid_instruction} ** 256;

    table[0xA9] = .{ .mnemonic = .LDA, .addressing_mode = .immediate, .cycles = 2 };
    table[0xAA] = .{ .mnemonic = .TAX, .addressing_mode = .implied, .cycles = 2 };
    table[0xE8] = .{ .mnemonic = .INX, .addressing_mode = .implied, .cycles = 2 };
    table[0xCA] = .{ .mnemonic = .DEX, .addressing_mode = .implied, .cycles = 2 };
    table[0xC9] = .{ .mnemonic = .CMP, .addressing_mode = .immediate, .cycles = 2 };
    table[0xA0] = .{ .mnemonic = .LDY, .addressing_mode = .immediate, .cycles = 2 };
    table[0xA8] = .{ .mnemonic = .TAY, .addressing_mode = .implied, .cycles = 2 };
    table[0xC8] = .{ .mnemonic = .INY, .addressing_mode = .implied, .cycles = 2 };
    table[0x88] = .{ .mnemonic = .DEY, .addressing_mode = .implied, .cycles = 2 };

    break :blk table;
};
