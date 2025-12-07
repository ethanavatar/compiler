const std = @import("std");
const Tokenizer = @import("Tokenizer.zig");

test {
    _ = Tokenizer;
}

const source = 
    \\fn main() i32 {
    \\    let _f2  = 2.0;
    \\    let _f02 = 0.2;
    \\
    \\    let decimal_int     = 98222;
    \\    let hex_int         = 0xff;
    \\    let another_hex_int = 0xFF;
    \\    let octal_int       = 0o755;
    \\    let binary_int      = 0b11110000;
    \\
    \\    return 0;
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

    const f = parser.parseTopLevel() catch |e| switch (e) {
        error.UnexpectedToken => {
            const token = parser.tokens.get(parser.tokens_index);
            var line_start = token.offset;
            while (source[line_start - 1] != '\n'): (line_start -= 1) { }

            var line_end = token.offset;
            while (source[line_end] != '\n' and source[line_end] != '\r'): (line_end += 1) { }

            var line_number: usize = 0;
            for (0..line_end) |i| {
                if (source[i] == '\n') line_number += 1;
            }

            const source_line = source[line_start..line_end];
            const column = token.offset - line_start;
            std.debug.print("Expected {any}, but got {any} ({c})\n", .{
                parser.expected_token, token.kind,
                source[token.offset],
            });
            std.debug.print("{}:{}\n", .{ line_number, column });
            std.debug.print("{s}\n", .{ source_line });
            std.debug.print("{[value]c: >[column]}\n", .{ .value = '^', .column = column });

            return e;
        },
        else => return e,
    };

    std.debug.print("{any}\n", .{ parser.nodes.get(f) });
}

const NodeIndex  = u32;
const TokenIndex = u32;

const NodeKind = union(enum) {
    type_name,
    integer,
    float,
    let_statement: struct { identifier: NodeIndex, expression: NodeIndex },
    return_statement: struct { expression: NodeIndex },
    function_signature: struct { return_type: NodeIndex },
    function: struct { signature: NodeIndex, body: NodeIndex },
    block:    struct { statements: []NodeIndex },
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

    expected_token: ?Tokenizer.TokenKind = null,

    nodes: std.MultiArrayList(Node) = .empty,

    fn addNode(self: *Self) !NodeIndex {
        return @intCast(try self.nodes.addOne(self.allocator));
    }

    fn setNode(self: *Self, i: NodeIndex, n: Node) NodeIndex {
        self.nodes.set(i, n);
        return i;
    }

    fn appendNode(self: *Self, n: Node) !NodeIndex {
        const i = try self.addNode();
        return self.setNode(i, n);
    }

    fn peekTokenKind(self: *Self) Tokenizer.TokenKind {
        return self.tokens.items(.kind)[self.tokens_index];
    }

    fn nextToken(self: *Self) !TokenIndex {
        if (self.tokens_index + 1 >= self.tokens.len) {
            return error.UnexpectedEof;
        }

        const t = self.tokens_index;
        self.tokens_index += 1;
        return t;
    }

    fn expectToken(self: *Self, expected: Tokenizer.TokenKind) !TokenIndex {
        const actual = self.peekTokenKind();
        if (std.meta.eql(actual, expected)) {
            return try self.nextToken();
        } else {
            self.expected_token = expected;
            return error.UnexpectedToken;
        }
    }

    pub fn parseTopLevel(self: *Self) !NodeIndex {
        return switch (self.peekTokenKind()) {
            .keyword_fn => try self.parseFunction(),
            else => |kind| std.debug.panic("unknown top-level keyword {any}\n", .{ kind })
        };
    }

    fn recoverAfter(self: *Self, kind: Tokenizer.TokenKind) !void {
        while (!std.meta.eql(self.peekTokenKind(), kind)): (_ = try self.nextToken()) { }
        _ = try self.expectToken(kind);
    }

    fn parseBlock(self: *Self) !NodeIndex {
        const open_brace = try self.expectToken(.{ .character = '{' });

        var statements: std.ArrayList(NodeIndex) = .empty;
        while (!std.meta.eql(self.peekTokenKind(), .{ .character = '}' })) {

            const statement = self.parseStatement() catch {
                try self.recoverAfter(.{ .character = ';' });
                continue;
            };

            try statements.append(self.allocator, statement);
        }

        _ = try self.expectToken(.{ .character = '}' });
        return self.appendNode(.{
            .kind = .{ .block = .{ .statements = statements.items } },
            .token = open_brace,
        });
    }

    fn parseFunction(self: *Self) !NodeIndex {
        const keyword = self.tokens_index;
        const signature = try self.parseFunctionSignature();
        const body = try self.parseBlock();

        return self.appendNode(.{
            .kind = .{ .function = .{ 
                .signature = signature,
                .body = body,
            } },
            .token = keyword,
        });
    }

    fn parseFunctionSignature(self: *Self) !NodeIndex {
        const index = try self.addNode();
        const keyword = try self.expectToken(.keyword_fn);

        _ = try self.expectToken(.identifier);
        _ = try self.expectToken(.{ .character = '(' });
        _ = try self.expectToken(.{ .character = ')' });
        const return_type = try self.parseTypeExpression();

        return self.setNode(index, .{
            .kind = .{ .function_signature = .{ .return_type = return_type } },
            .token = keyword,
        });
    }

    fn parseTypeExpression(self: *Self) !NodeIndex {
        return try self.appendNode(.{
            .kind = .type_name,
            .token = try self.expectToken(.identifier),
        });
    }

    fn parseStatement(self: *Self) !NodeIndex {
        return switch (self.peekTokenKind()) {
            .keyword_let => try self.parseLetStatement(),
            .keyword_return => try self.parseReturnStatement(),
            else => |kind| std.debug.panic("unknown top-level keyword {any}\n", .{ kind })
        };
    }

    fn parseLetStatement(self: *Self) !NodeIndex {
        const let_keyword = try self.expectToken(.keyword_let);
        const identifier  = try self.expectToken(.identifier);

        _ = try self.expectToken(.{ .character = '=' });
        const expression = try self.parseExpression();
        _ = try self.expectToken(.{ .character = ';' });

        return try self.appendNode(.{
            .kind = .{ .let_statement = .{
                .identifier = identifier,
                .expression = expression,
            } },
            .token = let_keyword,
        });
    }

    fn parseReturnStatement(self: *Self) !NodeIndex {
        const keyword = try self.expectToken(.keyword_return);
        const expression = try self.parseExpression();
        _ = try self.expectToken(.{ .character = ';' });

        return try self.appendNode(.{
            .kind = .{ .return_statement = .{ .expression = expression } },
            .token = keyword,
        });
    }

    fn parseExpression(self: *Self) !NodeIndex {
        const token_kind = self.peekTokenKind();
        const token = try self.nextToken();
        const kind: NodeKind = switch (token_kind) {
            .integer => .integer,
            .float   => .float,
            else => |t| std.debug.panic("expected expression, got token {any}", .{ t }),
        };

        return try self.appendNode(.{
            .kind = kind,
            .token = token,
        });
    }
};
