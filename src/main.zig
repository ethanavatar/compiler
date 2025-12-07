const std = @import("std");
const Tokenizer = @import("Tokenizer.zig");

const source = 
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
    \\
    \\fn add(a: i32, b: i32) i32 {
    \\    return a + b;
    \\}
;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var tokens: std.MultiArrayList(Tokenizer.Token) = .empty;
    defer tokens.deinit(allocator);

    var iter = Tokenizer.init(source);
    while (true) {
        const token = iter.next();
        try tokens.append(allocator, token);
        if (token.kind == .eof) break;
    }

    var parser: Parser = .{ 
        .allocator = allocator,
        .tokens = tokens
    };
    const f = try parser.parseFunctionSignature();
    std.debug.print("{any}\n", .{ parser.nodes.get(f) });

    //var buffer: [1024]u8 = undefined;
    //var stdout_writer = std.fs.File.stdout().writer(&buffer);
    //const writer = &stdout_writer.interface;
    //defer writer.flush() catch { };

    //for (tokens.items(.kind), tokens.items(.offset)) |kind, offset| {
    //    try writer.print("{}: {any}\n", .{ offset, kind });
    //}

    //try std.testing.expectEqual(tokens.items(.kind)[0], .keyword_fn);
}

const NodeIndex  = u32;
const TokenIndex = u32;

const NodeKind = union(enum) {
    identifier,
    function_signature: struct { return_type: NodeIndex },
};

const Node = struct {
    kind: NodeKind,
    token: TokenIndex,
};

const Parser = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    tokens: std.MultiArrayList(Tokenizer.Token),
    tokens_index: TokenIndex = 0,

    nodes: std.MultiArrayList(Node) = .empty,

    inline fn addNode(self: *Self) !NodeIndex {
        return @intCast(try self.nodes.addOne(self.allocator));
    }

    inline fn setNode(self: *Self, i: NodeIndex, n: Node) NodeIndex {
        self.nodes.set(i, n);
        return i;
    }

    inline fn appendNode(self: *Self, n: Node) !NodeIndex {
        const i = try self.addNode();
        return self.setNode(i, n);
    }

    inline fn nextToken(self: *Self) TokenIndex {
        const t = self.tokens_index;
        self.tokens_index += 1;
        return t;
    }

    fn expectToken(self: *Self, expected: Tokenizer.TokenKind) TokenIndex {
        const actual = self.tokens.items(.kind)[self.tokens_index];
        return if (std.meta.eql(actual, expected))
            self.nextToken() else std.debug.panic("expected {any} but got {any}\n", .{ expected, actual });
    }

    pub fn parseFunctionSignature(self: *Self) !NodeIndex {
        const index = try self.addNode();
        const keyword = self.expectToken(.keyword_fn);

        _ = self.expectToken(.identifier);
        _ = self.expectToken(.{ .character = '(' });
        _ = self.expectToken(.{ .character = ')' });
        const return_type = try self.parseTypeExpression();

        return self.setNode(index, .{
            .kind = .{ .function_signature = .{ .return_type = return_type } },
            .token = keyword,
        });
    }

    fn parseTypeExpression(self: *Self) !NodeIndex {
        return try self.appendNode(.{
            .kind = .identifier,
            .token = self.expectToken(.identifier),
        });
    }
};
