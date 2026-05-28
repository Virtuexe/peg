package cparser

import "core:mem"
import "core:mem/virtual"
import "core:unicode/utf8"

Context :: struct {
    arena:   virtual.Arena,
    pattern: Pattern,
    result:  Match_Result,
}

Match_Result :: struct {
    name: string,
    label: string,
    is_matching: bool,
    // Using a dynamic array makes zero/one-or-more logic much easier to build
    next: [dynamic]Match_Result, 
    text: string,
}

Pattern :: union {
    Match_String,
    Match_Range,
    Sequence,
    Choice,
    Optional,       // ?
    Zero_Or_More,   // *
    One_Or_More,    // +
    Lookahead,      // & (And-predicate)
    Not_Predicate,  // ! (Not-predicate)
    Match_Any,      // .
    EOF,            // End of File
    Capture,
    Label,
    ^Pattern,
}

//intstead of []Pattern use function 'array'
//intead of ^Pattern use 'ptr'

Match_String  :: struct { val: string }
Match_Range   :: struct { min, max: rune }
Sequence      :: struct { items: []Pattern }
Choice        :: struct { options: []Pattern }
Optional      :: struct { p: ^Pattern }
Zero_Or_More  :: struct { p: ^Pattern }
One_Or_More   :: struct { p: ^Pattern }
Lookahead     :: struct { p: ^Pattern }
Not_Predicate :: struct { p: ^Pattern }
Match_Any     :: struct {}
EOF           :: struct {}
Capture       :: struct { name: string, p: ^Pattern }
Label         :: struct { name: string, p: ^Pattern }

init :: proc() -> (res: Context) {
    _ = virtual.arena_init_growing(&res.arena)
    return res
}
destroy :: proc(ctx: ^Context) {
    virtual.arena_destroy(&ctx.arena)
}

build :: proc(ctx: ^Context, pattern: Pattern) {
    ctx.pattern = pattern
}

parse :: proc(ctx: ^Context, text: string) {
    idx := 0
    _parse(ctx, text, &idx, ctx.pattern, &ctx.result)
}

_parse :: proc(ctx: ^Context, text: string, idx: ^int, pattern: Pattern, res: ^Match_Result) -> bool {
    start := idx^
    context.allocator = virtual.arena_allocator(&ctx.arena)

    switch p in pattern {
    case Match_String:
        if start + len(p.val) <= len(text) && text[start:start+len(p.val)] == p.val {
            idx^ += len(p.val)
            res.is_matching = true
            res.text = text[start:idx^]
            return true
        }

    case Match_Range:
        if start < len(text) {
            r, width := utf8.decode_rune_in_string(text[start:])
            if r >= p.min && r <= p.max {
                idx^ += width
                res.is_matching = true
                res.text = text[start:idx^]
                return true
            }
        }

    case Sequence:
        original_len := len(res.next)
        matched := true
        for item in p.items {
            if !_parse(ctx, text, idx, item, res) {
                matched = false
                break
            }
        }
        if matched {
            res.is_matching = true
            res.text = text[start:idx^]
            return true
        }
        resize(&res.next, original_len)

    case Choice:
        original_len := len(res.next)
        for option in p.options {
            if _parse(ctx, text, idx, option, res) {
                res.is_matching = true
                res.text = text[start:idx^]
                return true
            }
            resize(&res.next, original_len)
        }

    case Optional:
        temp_idx := idx^
        original_len := len(res.next)
        if _parse(ctx, text, &temp_idx, p.p^, res) {
            idx^ = temp_idx
        } else {
            resize(&res.next, original_len)
        }
        res.is_matching = true
        res.text = text[start:idx^]
        return true

    case Zero_Or_More:
        for {
            temp_idx := idx^
            original_len := len(res.next)
            if _parse(ctx, text, &temp_idx, p.p^, res) {
                if temp_idx == idx^ { break }
                idx^ = temp_idx
            } else {
                resize(&res.next, original_len)
                break
            }
        }
        res.is_matching = true
        res.text = text[start:idx^]
        return true

    case One_Or_More:
        temp_idx := idx^
        original_len := len(res.next)
        if !_parse(ctx, text, &temp_idx, p.p^, res) {
            resize(&res.next, original_len)
            return false
        }
        idx^ = temp_idx
        for {
            temp_idx = idx^
            loop_len := len(res.next)
            if _parse(ctx, text, &temp_idx, p.p^, res) {
                if temp_idx == idx^ { break }
                idx^ = temp_idx
            } else {
                resize(&res.next, loop_len)
                break
            }
        }
        res.is_matching = true
        res.text = text[start:idx^]
        return true

    case Lookahead:
        temp_idx := idx^
        dummy_res: Match_Result
        if _parse(ctx, text, &temp_idx, p.p^, &dummy_res) {
            res.is_matching = true
            res.text = text[start:idx^]
            return true
        }
        return false

    case Not_Predicate:
        temp_idx := idx^
        dummy_res: Match_Result
        if _parse(ctx, text, &temp_idx, p.p^, &dummy_res) {
            return false
        }
        res.is_matching = true
        res.text = text[start:idx^]
        return true

    case Match_Any:
        if start < len(text) {
            _, width := utf8.decode_rune_in_string(text[start:])
            idx^ += width
            res.is_matching = true
            res.text = text[start:idx^]
            return true
        }

    case EOF:
        if start == len(text) {
            res.is_matching = true
            res.text = text[start:idx^]
            return true
        }

    case Capture:
        child_res: Match_Result
        temp_idx := idx^
        if _parse(ctx, text, &temp_idx, p.p^, &child_res) {
            child_res.name = p.name
            child_res.is_matching = true
            child_res.text = text[idx^ : temp_idx]

            idx^ = temp_idx
            append(&res.next, child_res)

            res.is_matching = true
            res.text = text[start:idx^]
            return true
        }
        return false

    case Label:
        original_len := len(res.next)
        if _parse(ctx, text, idx, p.p^, res) {
            if len(res.next) > original_len {
                res.next[len(res.next)-1].label = p.name
            }
            return true
        }
        return false

    case ^Pattern:
        if _parse(ctx, text, idx, p^, res) {
            res.is_matching = true
            res.text = text[start:idx^]
            return true
        }
    }

    idx^ = start
    res.is_matching = false
    return false
}

find_label :: proc(node: ^Match_Result, label: string) -> ^Match_Result {
    for &child in node.next {
        if child.label == label {
            return &child
        }
    }
    return nil // Not found (useful for optional fields)
}
