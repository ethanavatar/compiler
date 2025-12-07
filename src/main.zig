const std = @import("std");
const Token = @import("Token.zig");
const Tokenizer = @import("Tokenizer.zig");

const source = 
    \\fn add(a: i32, b: i32) i32 {
    \\    return a + b;
    \\}
    \\
    \\fn main() void {
    \\    let _f2  = 2.0;
    \\    let _f02 = 0.2;
    \\
    \\    let decimal_int     = 98222;
    \\    let hex_int         = 0xff;
    \\    let another_hex_int = 0xFF;
    \\    let octal_int       = 0o755;
    \\    let binary_int      = 0b11110000;
    \\}
;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var tokens: std.MultiArrayList(Token.Token) = .empty;
    defer tokens.deinit(allocator);

    var iter = Tokenizer.init(source);
    while (true) {
        const token = iter.next();
        try tokens.append(allocator, token);
        if (token.kind == .eof) break;
    }

    var buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&buffer);
    const writer = &stdout_writer.interface;
    defer writer.flush() catch { };

    for (tokens.items(.kind), tokens.items(.offset)) |kind, offset| {
        try writer.print("{}: {any}\n", .{ offset, kind });
    }
}

