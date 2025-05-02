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

        status = try execute(gpa, args);

    }

}

fn execute(gpa: Allocator, args: [][]const u8) !Status {

    if (args.len == 0) {
        return Status.okey;
    }

    if (std.meta.stringToEnum(BuiltinCommmand, args[0])) |cmd| {
        switch (cmd) {
            .exit => return Status.abort,
            .cd => {return Status.okey;}, // TODO: fix,
            .help => {
                try help();
                return Status.okey;
            }


        }
    }

    return try launch(gpa, args);
}

fn splitLine(gpa: Allocator, line: []const u8) ![][]const u8 {

    var token_array = ArrayList([]const u8).empty;
    errdefer token_array.deinit(gpa);

    var iterator = std.mem.tokenizeAny(u8, line, " \t\r\n\x07");

    var i: usize = 1;
    while (iterator.next()) |token| {
        log.debug("word {} = {s}", .{i, token});
        try token_array.append(gpa, token);
        i += 1;

    }

    return try token_array.toOwnedSlice(gpa);

}

fn launch(gpa: Allocator, args: [][]const u8) !Status {

    var status: Status = undefined;
    const pid = std.c.fork();

    std.debug.print("new pid = {}\n", .{pid});

    var env_map = try std.process.getEnvMap(gpa);
    defer env_map.deinit();
    if (pid == 0) {
        // child process
        
        std.process.execve(gpa, args, &env_map) catch {
            std.debug.print("lsh: failed to execute {s}\n", .{args[0]});
        };

        return Status.abort;

    } else if (pid < 0) {
        // error forking
        std.debug.print("failed to fork\n", .{});
        return Status.abort;
        
    } else {
        // parent process

        var wpid = std.c.waitpid(pid, @ptrCast(&status), getWuntraced());

        while (!wifexited(@intFromEnum(status)) and !wifsignaled(@intFromEnum(status))) {
           wpid = std.c.waitpid(pid, @ptrCast(&status), getWuntraced());
        }
    }

    return Status.okey;

}

// 
extern "c" fn getWuntraced() c_int;
extern "c" fn wifexited(status: c_int) bool;
extern "c" fn wifsignaled(status: c_int) bool;
extern "c" fn execvp(path: [*:0]const u8, argv: [*:null]const ?[*:0]const u8) c_int;

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
