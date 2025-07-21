const std = @import("std");
const Nyxx = @import("nyxx.zig").Nyxx;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        return error.InvalidArgument;
    }

    const path = args[1];
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try allocator.alloc(u8, @intCast(file_size));
    defer allocator.free(buffer);

    _ = try file.readAll(buffer);

    var nyxx = try Nyxx.init(allocator, buffer);
    defer nyxx.deinit();

    try nyxx.run();
}
