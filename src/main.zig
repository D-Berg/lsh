const std = @import("std");
const builtin = @import("builtin");
var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

const lsh = @import("lsh.zig");

pub fn main() !void {

    const gpa, const is_debug = blk: {
        break :blk switch (builtin.mode) {
            .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
            .ReleaseSmall, .ReleaseFast => .{ std.heap.smp_allocator, false }
        };
    };
    defer if (is_debug) {
        _ = debug_allocator.deinit();
    };

    // load config files
    

    // run command loop

    try lsh.loop(gpa);
        

    // cleanup

}
