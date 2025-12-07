pub const TokenKind = enum {
    eof,
    illegal,
    unknown,

    identifier,
    integer,
    float,
    character,
    comment,
};

pub const Token = struct {
    kind: TokenKind,
    offset: u32,
};
