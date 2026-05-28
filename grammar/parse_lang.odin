package parse_lang
import c "../"

build :: proc() -> c.Context {
    ctx := c.init()
    context.allocator = c.allocator(&ctx)

    char := c.seq(c.str(`'`), c.any_c(), c.str(`'`))
    range := c.cap("Range", c.seq(char, c.str(`-`), char))

    string_lit1 := c.seq(
        c.str(`"`), 
        c.z_o_m(c.seq(
            c.not(c.str(`"`)), 
            c.any_c()
        )), 
        c.str(`"`)
    )
    string_lit2 := c.seq(
        c.str("`"), 
        c.z_o_m(c.seq(
            c.not(c.str("`")), 
            c.any_c()
        )), 
        c.str("`")
    )
    string_lit := c.cap("String", c.choice(string_lit1, string_lit2))

    prefix := c.cap("Prefix", c.choice(c.str("&"), c.str("!")))
    suffix := c.cap("Suffix", c.choice(c.str("?"), c.str("*"), c.str("+")))
    binary := c.cap("Binary", c.choice(c.str(" "), c.str("|")))
    
    expression := new(c.Pattern)
    any_c := c.cap("Any", c.str("."))
    group := c.cap("Group", c.seq(c.str("("), c.lbl("inner", expression), c.str(")")))
    value := c.choice(any_c, range, string_lit, group)
    first_char := c.choice(
        c.range('a', 'z'),
        c.range('A', 'Z'),
        c.str("_")
    )
    rest_char := c.choice(
        c.range('a', 'z'),
        c.range('A', 'Z'),
        c.str("_"),
        c.range('0', '9')
    )
    name := c.seq(first_char, c.z_o_m(rest_char))
    capture := c.cap("CaptureTag", c.seq(c.str("<"), name, c.str(">")))
    label := c.cap("LabelTag", c.seq(name, c.str(":")))
    object := c.cap("Object", c.seq(
        c.lbl("capture", c.opt(capture)),
        c.lbl("label", c.opt(label)),
        c.lbl("prefix", c.opt(prefix)), 
        c.lbl("value", value), 
        c.lbl("suffix", c.opt(suffix))
    ))
    expression^ = c.cap("Expression", c.seq(
        c.lbl("left", object), 
        c.opt(c.seq(c.lbl("op", binary), 
        c.lbl("right", expression)))
    ))

    c.build(&ctx, expression^)
    return ctx
}

build_parser :: proc(node: ^c.Match_Result) -> (res: c.Context) {
    res = c.init()
    context.allocator = c.allocator(&res)
    root_pattern := build_pattern(node)
    c.build(&res, root_pattern)
    return
}
// This walks the AST and builds executable PEG Patterns dynamically in memory!
build_pattern :: proc(node: ^c.Match_Result) -> c.Pattern {
    if node == nil {
        return c.str("") // Safe fallback
    }

    switch node.name {
    case "Any":
        return c.any_c()
    case "String":
        // node.text includes the literal quotes (e.g., `"hello"`). 
        // We must slice the string to strip the first and last characters!
        clean_str := node.text[1 : len(node.text)-1]
        return c.str(clean_str)

    case "Range":
        // node.text is exactly `'a'-'z'`.
        // The actual characters are at index 1 and 5.
        min_rune := rune(node.text[1])
        max_rune := rune(node.text[5])
        return c.range(min_rune, max_rune)

    case "Group":
        // A group just passes the inner pattern upwards
        inner := c.find_label(node, "inner")
        return build_pattern(inner)

    case "Object":
        // 1. Generate the core pattern first
        value_node := c.find_label(node, "value")
        result := build_pattern(value_node)

        // 2. Wrap it in a suffix if it has one
        suffix := c.find_label(node, "suffix")
        if suffix != nil {
            if suffix.text == "+" do result = c.o_o_m(result)
            if suffix.text == "*" do result = c.z_o_m(result)
            if suffix.text == "?" do result = c.opt(result)
        }

        // 3. Wrap it in a prefix if it has one
        prefix := c.find_label(node, "prefix")
        if prefix != nil {
            if prefix.text == "!" do result = c.not(result)
            if prefix.text == "&" do result = c.look(result)
        }

        // 4. Wrap in a Capture
        cap_node := c.find_label(node, "capture")
        if cap_node != nil {
            // text is `<MyNode>`, so we strip the first and last character
            clean_cap := cap_node.text[1 : len(cap_node.text)-1]
            result = c.cap(clean_cap, result)
        }

        // 5. Wrap in a Label
        lbl_node := c.find_label(node, "label")
        if lbl_node != nil {
            // text is `my_label:`, so we strip ONLY the last character
            clean_lbl := lbl_node.text[0 : len(lbl_node.text)-1]
            result = c.lbl(clean_lbl, result)
        }

        return result

    case "Expression":
        // 1. Build the left side
        left := build_pattern(c.find_label(node, "left"))
        
        // 2. Check for an operator
        op_node := c.find_label(node, "op")
        right_node := c.find_label(node, "right")

        if op_node != nil && right_node != nil {
            // Build the right side
            right := build_pattern(right_node)
            
            // Apply the Binary logic directly!
            if op_node.text == "|" {
                return c.choice(left, right)
            } else {
                return c.seq(left, right)
            }
        }
        return left
    }
    
    return c.str("")
}