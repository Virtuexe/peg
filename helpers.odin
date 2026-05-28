package cparser
import "core:slice"
import "core:mem/virtual"
import "core:mem"

allocator :: proc(ctx: ^Context) -> mem.Allocator {
    return virtual.arena_allocator(&ctx.arena)
}

array :: proc(patterns: ..Pattern) -> []Pattern {
    return slice.clone(patterns)
}

ptr :: proc(pattern: Pattern) -> ^Pattern {
    return new_clone(pattern)
}

// --- Syntax Sugar ---
str   :: proc(val: string) -> Pattern { return Match_String{val = val} }
range :: proc(from, to: rune) -> Pattern { return Match_Range{from, to} }
any_c :: proc() -> Pattern            { return Match_Any{} }
eof   :: proc() -> Pattern            { return EOF{} }

seq :: proc(patterns: ..Pattern) -> Pattern {
    return Sequence{items = array(..patterns)}
}

choice :: proc(options: ..Pattern) -> Pattern {
    return Choice{options = array(..options)}
}

opt   :: proc(p: Pattern) -> Pattern { return Optional{p = ptr(p)} }
z_o_m :: proc(p: Pattern) -> Pattern { return Zero_Or_More{p = ptr(p)} }
o_o_m :: proc(p: Pattern) -> Pattern { return One_Or_More{p = ptr(p)} }
look  :: proc(p: Pattern) -> Pattern { return Lookahead{p = ptr(p)} }
not   :: proc(p: Pattern) -> Pattern { return Not_Predicate{p = ptr(p)} }

cap :: proc(name: string, p: Pattern) -> Pattern {
    return Capture{name = name, p = ptr(p)}
}
lbl :: proc(name: string, p: Pattern) -> Pattern {
    return Label{name = name, p = ptr(p)}
}