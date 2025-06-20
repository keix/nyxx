const std = @import("std");

// Import test modules and reference them to include their tests
test {
    _ = @import("tests/cpu.zig");
    _ = @import("tests/ppu.zig");
    _ = @import("tests/apu.zig");
}
