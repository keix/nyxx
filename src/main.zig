const std = @import("std");
const Bus = @import("bus.zig").Bus;
const CPU = @import("6502.zig").CPU;
const Cart = @import("cartridge.zig").Cartridge;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const allocator = std.heap.page_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try stdout.print("Usage: {s} $ROM_FILE_PATH\n", .{args[0]});
        return error.InvalidArgument;
    }

    const path = args[1];
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try allocator.alloc(u8, file_size);
    defer allocator.free(buffer);

    _ = try file.readAll(buffer);

    var cartridge = try Cart.loadFromFile(allocator, buffer);
    defer cartridge.deinit(allocator);

    var bus = Bus.init(&cartridge);
    var cpu = CPU.init(&bus);

    try stdout.print("Initial PC: 0x{X:0>4}\n", .{cpu.registers.pc});

    const reset_low = bus.read(0xFFFC);
    const reset_high = bus.read(0xFFFD);
    const reset_vector = @as(u16, reset_low) | (@as(u16, reset_high) << 8);

    try stdout.print("Read reset vector: 0x{X:0>4}\n", .{reset_vector});

    var total_cycles: usize = 0;
    var instruction_count: usize = 0;

    try stdout.print("Starting execution...\n", .{});

    while (instruction_count < 40) {
        const pc_before = cpu.registers.pc;
        const opcode = bus.read(cpu.registers.pc);

        try stdout.print("Instruction {}: PC=0x{X:0>4}, opcode=0x{X:0>2}", .{ instruction_count, pc_before, opcode });

        const cycles = cpu.step();
        total_cycles += cycles;
        instruction_count += 1;

        try stdout.print(" -> PC=0x{X:0>4}, cycles={}\n", .{ cpu.registers.pc, cycles });

        if (cpu.registers.pc == pc_before) {
            try stdout.print("Infinite loop detected at PC=0x{X:0>4}\n", .{pc_before});
            break;
        }
    }

    try stdout.print("Total cycles: {}\n", .{total_cycles});
}
