const std = @import("std");
const Token = @import("Token.zig");
const TokenKind = Token.TokenKind;

const Self = @This();

source: [:0]const u8,
offset: usize,

pub fn init(source: [:0]const u8) Self {
    return .{ .source = source, .offset = 0 };
}

pub fn next(self: *Self) Token.Token {
    var state: State = .Start;
    var token_length: usize = 0;

    var kind: TokenKind = .unknown;
    while (!finalState(state, &kind)) {
        const c = self.source[self.offset + token_length];
        state = transition(state, c);

        const advance = stateAdvance(state);
        token_length += @intCast(advance.token);
        self.offset  += @intCast(advance.cursor);
    }

    const token_start = self.offset;
    self.offset += token_length;

    std.debug.assert(kind != .unknown);
    return .{
        .kind = kind,
        .offset = @intCast(token_start),
    };
}

const State = enum(u8) {
    Illegal,
    Start,
    Eof,

    Character,

    InIdentifier, EndIdentifier,

    FoundZero,
    InNumber, EndInteger,
    InFloat, EndFloat,
    InHex, EndHex,
    InBinary, EndBinary,
    InOctal, EndOctal,

    FoundForwardSlash, EndForwardSlash,
    InLineComment, EndLineComment,
};

const Advance = struct {
    const T = i8;
    pub const zero: @This() = .{ .cursor = 0, .token = 0 };
    pub const one:  @This() = .{ .cursor = 0, .token = 1 };
    pub const skip: @This() = .{ .cursor = 1, .token = 0 };
    cursor: T, token: T,
};

fn stateAdvance(state: State) Advance {
    return switch (state) {
        .Start           => .skip,
        .Eof             => .zero,

        .EndIdentifier   => .zero,
        .EndInteger      => .zero,
        .EndFloat        => .zero,
        .EndHex          => .zero,
        .EndBinary       => .zero,
        .EndOctal        => .zero,

        .EndForwardSlash => .zero,
        .EndLineComment  => .zero,

        else => .one,
    };
}

fn finalState(state: State, kind: *TokenKind) bool {
    kind.* = switch (state) {
        .Eof            => .eof,
        .Illegal        => .illegal,

        .EndIdentifier  => .identifier,
        .EndInteger     => .integer,
        .EndHex         => .integer,
        .EndBinary      => .integer,
        .EndOctal       => .integer,
        .EndFloat       => .float,

        .EndForwardSlash => .character,
        .EndLineComment => .comment,
        .Character      => .character,

        else => .unknown,
    };

    return kind.* != .unknown;
}

fn transition(state: State, c: u8) State {
    return switch (state) {
        .Start => switch (c) {
            0 => .Eof,

            ' ', '\t'...'\r' => .Start, // Skip
            'a'...'z', 'A'...'Z', '_' => .InIdentifier,

            '0' => .FoundZero,
            '1'...'9' => .InNumber,

            '/' => .FoundForwardSlash,
            else => .Character,
        },
        .FoundForwardSlash => switch (c) {
            '/' => .InLineComment,
            else => .EndForwardSlash,
        },
        .InLineComment => switch (c) {
            '\n' => .EndLineComment,
            else => .InLineComment,
        },
        .InIdentifier => switch (c) {
            'a'...'z', 'A'...'Z', '_', '0'...'9' => .InIdentifier,
            else => .EndIdentifier,
        },
        .FoundZero => switch (c) {
            '0'...'9' => .InNumber,
            'x' => .InHex,
            'b' => .InBinary,
            'o' => .InOctal,
            else => .EndInteger,
        },
        .InHex => switch (c) {
            'a'...'z', 'A'...'Z', '_', '0'...'9' => .InHex,
            else => .EndHex,
        },
        .InBinary => switch (c) {
            '0'...'9' => .InBinary,
            else => .EndBinary,
        },
        .InOctal => switch (c) {
            '0'...'9' => .InBinary,
            else => .EndOctal,
        },
        .InNumber => switch (c) {
            '0'...'9' => .InBinary,
            '.' => .InFloat,
            else => .EndInteger,
        },
        .InFloat => switch (c) {
            '0'...'9' => .InFloat,
            else => .EndFloat,
        },
        else => std.debug.panic("unhandled state: {any}", .{ state }),
    };
}

