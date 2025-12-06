const std = @import("std");
const Tokenizer = @import("Tokenizer.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const source = 
        \\pub fn add(a: i32, b: i32) i32 {
        \\    c = 42; 
        \\    _ = c; // Unused
        \\    return a + b;
        \\}
        \\
        \\pub fn main() !void {
        \\    const _f2  = 2.0;
        \\    const _f02 = 0.2;
        \\
        \\    const decimal_int = 98222;
        \\    const hex_int = 0xff;
        \\    const another_hex_int = 0xFF;
        \\    const octal_int = 0o755;
        \\    const binary_int = 0b11110000;
        \\}
    ;

    var tokens: std.MultiArrayList(Tokenizer.Token) = .empty;
    defer tokens.deinit(allocator);

    var iter = Tokenizer.init(source);
    while (true) {
        const token = iter.next();
        try tokens.append(allocator, token);
        if (token.kind == .eof) break;
    }

    var buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&buffer);
    defer stdout_writer.end() catch { };

    const writer = &stdout_writer.interface;

    for (tokens.items(.kind), tokens.items(.offset)) |kind, offset| {
        try writer.print("{}: {any}\n", .{ offset, kind });
    }
}

