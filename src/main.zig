const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena = init.arena.allocator();

    const args = try init.minimal.args.toSlice(arena);
    if (args.len < 2) {
        std.log.err("Usage: zwhich <command>...", .{});
        std.process.exit(2);
    }

    const path_env = init.environ_map.get("PATH") orelse {
        std.log.err("PATH is not set", .{});
        std.process.exit(2);
    };

    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buf);
    const stdout = &stdout_writer.interface;

    var all_found = true;
    for (args[1..]) |name| {
        if (try which(io, arena, path_env, name)) |full| {
            try stdout.print("{s}\n", .{full});
        } else {
            all_found = false;
        }
    }
    try stdout.flush();

    if (!all_found) std.process.exit(1);
}

/// Searches for an executable file in the directories listed in PATH.
/// Returns the full path to the executable if found, or null if not found.
fn which(
    io: std.Io,
    arena: std.mem.Allocator,
    path_env: []const u8,
    name: []const u8,
) !?[]const u8 {
    const cwd = std.Io.Dir.cwd();

    var it = std.mem.tokenizeScalar(u8, path_env, std.fs.path.delimiter);
    while (it.next()) |dir| {
        const candidate = try std.fs.path.join(arena, &.{ dir, name });

        cwd.access(io, candidate, . { .execute = true }) catch |err| switch (err) {
            error.FileNotFound, error.AccessDenied, error.PermissionDenied => continue,
            else => return err,
        };
        return candidate;
    }
    return null;
}
