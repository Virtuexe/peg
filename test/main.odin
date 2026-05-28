package test

import "core:fmt"
import l "../parse_lang"
import p "../"

main :: proc() {
    ctx := l.build()
    source_code := "<function>(`function {` (!`}` .)* `}`)"
    p.parse(&ctx, source_code)
    if !ctx.result.is_matching {
        fmt.println("Syntax Error: Failed to parse the grammar!")
        return
    }
    new_ctx := l.build_parser(&ctx.result.next[0])
    user_code := "function {hello world}"
    p.parse(&new_ctx, user_code)
    if !new_ctx.result.is_matching {
        fmt.println("Syntax Error: Failed to parse the grammar! (User)")
        return
    }

    if new_ctx.result.is_matching {
        fmt.println(new_ctx.result.text)
    }
    else {
        fmt.println("not found")
    }
}