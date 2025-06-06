const std = @import("std");
const Bus = @import("bus.zig").Bus;
const CPU = @import("6502.zig").CPU;
const Cart = @import("cartridge.zig").Cartridge;
const FrameBuffer = @import("ppu.zig").FrameBuffer;

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

    var fb = FrameBuffer{};

    try stdout.print("Starting execution...\n", .{});
    var frame_counter: usize = 0;

    for (0..550) |frame_num| {
        var frame_cycles: u32 = 0;
        const target_cycles = 29780;

        while (frame_cycles < target_cycles) {
            const cycles = cpu.step();
            frame_cycles += cycles;

            for (0..(cycles * 3)) |_| {
                try bus.ppu.step(&fb);
            }

            if (bus.ppu.registers.status.vblank and !bus.ppu._vblank_injected) {
                bus.ppu._vblank_injected = true;
                break;
            }
        }

        if (frame_num % 10 == 0) {
            const filename = try std.fmt.allocPrint(allocator, "test-results/framebuffer_{d:0>2}.ppm", .{frame_num});
            defer allocator.free(filename);
            try fb.writePPM(filename);
        }

        // std.debug.print("Frame {}: {} cycles\n", .{ frame_num, frame_cycles });

        // if (frame_counter == 100) {
        //     bus.ppu.dumpNameTable();
        // }
        frame_counter += 1;
    }
}
