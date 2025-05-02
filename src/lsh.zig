const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const c = @import("c");
const log = std.log;

pub const Error = error {
    ChildProcess,
    
} || Allocator.Error || anyerror;

const Status = enum(c_int) {
    abort = 0,
    okey = 1,
    _,
};

const BuiltinCommmand = enum {
    cd,
    exit,
    help,
};

const wuntraced = getWuntraced();

pub fn loop(gpa: Allocator) !void {

    var status: Status = .okey;

    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();
    const stderr = std.io.getStdErr().writer();

    var buffer = std.ArrayListUnmanaged(u8).empty;
    errdefer buffer.deinit(gpa);

    const buff_writer = buffer.writer(gpa);

    while (status == .okey) {
        try stdout.print("> ", .{});

        try stdin.streamUntilDelimiter(buff_writer, '\n', null);

        const line = try buffer.toOwnedSlice(gpa);
        defer gpa.free(line);

        log.debug("line = {s}", .{line});

        const args = try splitLine(gpa, line);
        defer gpa.free(args);

        log.debug("args.len = {}", .{args.len});

        status = try execute(gpa, args, stderr.any());

    }

}

fn execute(gpa: Allocator, args: []const []const u8, stderr: std.io.AnyWriter) !Status {

    if (args.len == 0) {
        return Status.okey;
    }

    if (std.meta.stringToEnum(BuiltinCommmand, args[0])) |cmd| {
        switch (cmd) {
            .exit => return Status.abort,
            .cd => {
                if (args.len == 2) {
                    std.process.changeCurDir(args[1]) catch |err| {
                        try stderr.print("lsh: failed to change dir because of {s}\n", .{@errorName(err)});
                    };
                }
                return Status.okey;
            },
            .help => {
                try help();
                return Status.okey;
            }


        }
    }

    return try launch(gpa, args, stderr);
}

//TODO: dont split on ""
fn splitLine(gpa: Allocator, line: []const u8) ![]const []const u8 {

    var token_array = ArrayList([]const u8).empty;
    errdefer token_array.deinit(gpa);

    var iterator = std.mem.tokenizeAny(u8, line, " \t\r\n\x07");

    while (iterator.next()) |token| {
        try token_array.append(gpa, token);
    }

    return try token_array.toOwnedSlice(gpa);

}

fn launch(gpa: Allocator, args: []const []const u8, stderr: std.io.AnyWriter) !Status {


    var status: Status = undefined;
    const pid = std.posix.fork() catch {
        // error forking (still parent, since no child was created
        try stderr.print("failed to fork\n", .{});
        return Status.okey;
    };

    log.debug("new pid = {}\n", .{pid});
    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();

    const arena = arena_allocator.allocator();

    var argsv = try arena.allocSentinel(?[*:0]const u8, args.len, null);
    for (args, 0..) |arg, i| argsv[i] = try arena.dupeZ(u8, arg);

    if (pid == 0) {
        // in child process

        const err = std.posix.execvpeZ(argsv[0].?, argsv.ptr, std.c.environ);
        switch (err) {
            else => {
                try stderr.print(
                    "lsh: failed to execute {s} because of {s}\n", 
                    .{ args[0], @errorName(err) }
                );
            },
        }

        log.debug("exiting child", .{}); // only called if execvpeZ fails
        std.process.exit(1);

    }  else {

        // parent process
        var wpid = std.c.waitpid(pid, @ptrCast(&status), getWuntraced());

        while (!wifexited(@intFromEnum(status)) and !wifsignaled(@intFromEnum(status))) {
           wpid = std.c.waitpid(pid, @ptrCast(&status), getWuntraced());
        }
    }

    return Status.okey;

}


// c helper functions not found in zig std
extern "c" fn getWuntraced() c_int;
extern "c" fn wifexited(status: c_int) bool;
extern "c" fn wifsignaled(status: c_int) bool;

fn help() !void {

    const stdout = std.io.getStdOut().writer();

    try stdout.print("Stephen Brennan's LSH\n", .{});
    try stdout.print("Type program names and arguments, and hit enter.\n", .{});
    try stdout.print("The following are built in:\n", .{});
    
    inline for (@typeInfo(BuiltinCommmand).@"enum".fields) |field| {
        try stdout.print("  {s}\n", .{field.name});
    }

    try stdout.print("Use the man command for information on other programs.\n", .{});

}
