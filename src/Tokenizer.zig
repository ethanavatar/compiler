const std = @import("std");
const Self = @This();

source: [:0]const u8,
offset: usize,

pub const TokenKind = union(enum) {
    eof,

    identifier,
    integer,
    float,
    line_comment,

    keyword_fn,
    keyword_let,
    keyword_return,

    character: u8,
};

pub const Token = struct {
    kind: TokenKind,
    offset: u32,
};

const State = enum(u8) {
    start,

    identifier,
    integer,
    float,
    line_comment,
    
    slash,
};

// TODO: replace this with perfect hashing,
// because this does a linear search every time you want to match a keyword
const keywords = std.StaticStringMap(TokenKind).initComptime(&.{
    .{ "fn", .keyword_fn },
    .{ "let", .keyword_let },
    .{ "return", .keyword_return },
});

pub fn init(source: [:0]const u8) Self {
    return .{ .source = source, .offset = 0 };
}

pub fn next(self: *Self) Token {
    var token_start = self.offset;
    const kind: TokenKind = state: switch (State.start) {
        .start => switch (self.source[self.offset]) {
            0 => .eof,

            ' ', '\t'...'\r' => {
                token_start += 1;
                self.offset += 1;
                continue :state .start;
            },

            'a'...'z', 'A'...'Z', '_' => continue :state .identifier,
            '0'...'9' => continue :state .integer,

            '/' => continue :state .slash,
            else => {
                self.offset += 1;
                break :state .{ .character = self.source[self.offset - 1] };
            },
        },
        .slash => {
            self.offset += 1;
            switch (self.source[self.offset]) {
                '/' => continue :state .line_comment,
                else => break :state .{ .character = '/' },
            }
        },
        .line_comment => {
            self.offset += 1;
            switch (self.source[self.offset]) {
                '\n' => break :state .line_comment,
                else => continue :state .line_comment,
            }
        },
        .identifier => {
            self.offset += 1;
            switch (self.source[self.offset]) {
                'a'...'z', 'A'...'Z', '_', '0'...'9' => continue :state .identifier,
                else => break :state keywords.get(self.source[token_start..self.offset]) orelse .identifier,
            }
        },
        .integer => {
            self.offset += 1;
            switch (self.source[self.offset]) {
                '_', '0'...'9', 'a'...'z', 'A'...'Z' => continue :state .integer,
                '.' => continue :state .float,
                else => break :state .integer,
            }
        },
        .float => {
            self.offset += 1;
            switch (self.source[self.offset]) {
                '0'...'9' => continue :state .float,
                else => break :state .float,
            }
        },
    };

    //std.debug.print("{s}\t{any}\n", .{ self.source[token_start..self.offset], kind });
    return .{ .kind = kind, .offset = @intCast(token_start) };
}

test {
    var iter = init("0xFF");
    try std.testing.expectEqual(.integer, iter.next().kind);
    try std.testing.expectEqual(.eof,     iter.next().kind);
}
