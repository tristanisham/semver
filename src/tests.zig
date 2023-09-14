const std = @import("std");
const testing = std.testing;
const semver = @import("main.zig");

test "Canonical parsing" {
    const result = semver.canonical("v1");
    if (result) |y| {
        std.debug.print("{any}", .{y});
        try testing.expect(std.mem.eql(u8, y, "v1.0.0"));
    }
}
