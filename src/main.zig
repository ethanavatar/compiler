const std = @import("std");
const root = @import("root.zig");
const StaticIntegralMap = root.StaticIntegralMap;

const CharacterClass = enum(u8) {
    Eof,
    Digit, Letter, Whitespace,
    GenericCharacter,
};

const State = enum(u8) {
    Illegal,
    Start,
    Eof,

    GenericCharacter,

    InIdentifier,
    EndIdentifier,

    InInteger,
    EndInteger,
};

const character_class_map = StaticIntegralMap(u8, CharacterClass).init(.GenericCharacter, &.{
    .{ .pattern = .{ .basic =  0 }, .result = .Eof },

    .{ .pattern = .{ .range = .{ .start = '0', .end = '9' } }, .result = .Digit },
    .{ .pattern = .{ .range = .{ .start = 'a', .end = 'z' } }, .result = .Letter },
    .{ .pattern = .{ .range = .{ .start = 'A', .end = 'Z' } }, .result = .Letter },
    .{ .pattern = .{ .basic = '_' }, .result = .Letter },

    .{ .pattern = .{ .basic = ' ' }, .result = .Whitespace },
    .{ .pattern = .{ .range = .{ .start = '\t', .end = '\r' } }, .result = .Whitespace },
});

const CharacterClassToState = StaticIntegralMap(CharacterClass, State);
const default_transition = CharacterClassToState.init(State.Illegal, &.{});
const transition_map = StaticIntegralMap(State, CharacterClassToState).init(default_transition, &.{

    .{ .pattern = .{ .basic = .Start }, .result = CharacterClassToState.init(.Illegal, &.{
        .{ .pattern = .{ .basic = .Eof    }, .result = .Eof },
        .{ .pattern = .{ .basic = .Letter }, .result = .InIdentifier },
        .{ .pattern = .{ .basic = .Digit  }, .result = .InInteger },
        .{ .pattern = .{ .basic = .GenericCharacter }, .result = .GenericCharacter },
    }) },

    .{ .pattern = .{ .basic = .InIdentifier }, .result = CharacterClassToState.init(.EndIdentifier, &.{
        .{ .pattern = .{ .basic = .Letter }, .result = .InIdentifier },
        .{ .pattern = .{ .basic = .Digit  }, .result = .InIdentifier },
    }) },

    .{ .pattern = .{ .basic = .InInteger }, .result = CharacterClassToState.init(.EndInteger, &.{
        .{ .pattern = .{ .basic = .Digit  }, .result = .InInteger },
    }) },

});

const state_widths_map = StaticIntegralMap(State, u1).init(1, &.{
    .{ .pattern = .{ .basic =  .Eof           }, .result = 0 },
    .{ .pattern = .{ .basic =  .EndIdentifier }, .result = 0 },
    .{ .pattern = .{ .basic =  .EndInteger    }, .result = 0 },
});

const final_states_map = StaticIntegralMap(State, bool).init(false, &.{
    .{ .pattern = .{ .basic =  .Eof           }, .result = true },
    .{ .pattern = .{ .basic =  .Illegal       }, .result = true },
    .{ .pattern = .{ .basic =  .EndIdentifier }, .result = true },
    .{ .pattern = .{ .basic =  .EndInteger    }, .result = true },

    .{ .pattern = .{ .basic =  .GenericCharacter }, .result = true },
});

const TokenKind = union(enum) {
    illegal: void,
    identifier: void,
    integer: u32,

    keyword_pub: void,
    keyword_fn: void,

    type_void: void,
    type_i32: void,

    character: u8,
};

const keywords_map = std.StaticStringMap(TokenKind).initComptime(&.{
    .{ "pub",  .keyword_pub },
    .{ "fn",   .keyword_fn  },

    .{ "void", .type_void },
    .{ "i32",  .type_i32  },
});

const Tokenizer = struct {
    const Self = @This();

    source: [:0]const u8,
    offset: usize,

    pub fn init(source: [:0]const u8) Self {
        return .{ .source = source, .offset = 0 };
    }

    pub fn next(self: *Self) !?struct { []const u8, TokenKind } {
        if (self.offset >= self.source.len) return null;

        var state: State = .Start;
        var token_length: usize = 0;

        while (std.ascii.isWhitespace(self.source[self.offset])): (self.offset += 1) { }

        while (!final_states_map.get(state)) {
            const c = self.source[self.offset + token_length];
            const character_kind = character_class_map.get(c);
            state = transition_map.get(state).get(character_kind);
            token_length += state_widths_map.get(state);
        }

        const token = self.source[self.offset..(self.offset + token_length)];
        self.offset += token_length;

        const kind: TokenKind = switch (state) {
            .Illegal       => .illegal,
            .EndIdentifier => keywords_map.get(token) orelse .identifier,
            .EndInteger    => .{ .integer = try std.fmt.parseInt(u32, token, 10) },
            .GenericCharacter => .{ .character = token[0] },
            else => unreachable,
        };

        return .{ token, kind };
    }
};

pub fn main() !void {
    const source = 
        \\pub fn add(a: i32, b: i32) i32 {
        \\    c = 42;
        \\    return a + b;
        \\}
    ;

    var iter = Tokenizer.init(source);
    while (try iter.next()) |p| {
        const token, const kind = p;
        switch (kind) {
            .character => |c| std.debug.print("`{c}`\n", .{ c }),
            else => std.debug.print("`{s}`: {any}\n", .{ token, kind }),
        }
    }
}

