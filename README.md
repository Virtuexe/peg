```markdown
# Odin PEG Engine

A fast, dynamically compiled Parsing Expression Grammar (PEG) engine written in Odin.
It strictly handles **Syntax**—acting as a scannerless,
unambiguous parser that reads text and generates a structured,
labeled Abstract Syntax Tree (AST) using a virtual memory arena.

## Project Structure
```text
peg_engine/
 ├── core.odin         # Core VM, Context, and recursive evaluation loop
 ├── utils.odin        # Helper functions and memory utilities
 ├── grammar/
 │    └── builder.odin # Meta-compiler (turns grammar strings into runnable engines)
 └── tests/
      └── main.odin    # Implementation tests
```

## Grammar Syntax

| Operator | Type | Description |
| --- | --- | --- |
| `"abc"` / ``abc`` | **String** | Matches exact text. |
| `'a'-'z'` | **Range** | Matches a character within the range. |
| `.` | **Any** | Matches exactly one character. |
| `A B` | **Sequence** | Matches `A` followed immediately by `B`. |
| `A\|B` | **Choice** | Ordered choice. Tries `A`, if it fails, tries `B`. |
| `A*` | **Zero-or-More** | Matches `A` zero or more times. |
| `A+` | **One-or-More** | Matches `A` one or more times. |
| `A?` | **Optional** | Matches `A` zero or one time. |
| `&A` | **Lookahead** | Succeeds if `A` matches. Does *not* consume text. |
| `!A` | **Not-Predicate** | Succeeds if `A` does *not* match. Does *not* consume text. |
| `(A B)` | **Grouping** | Groups expressions together. |

## AST Generation & Rules

| Syntax | Description |
| --- | --- |
| `Rule = A` | *(Not implemented)* Defines a reusable grammar rule. |
| `RuleName` | *(Not implemented)* References a previously defined rule. |
| `<Name>A` | **Capture:** Wraps the matched text in an AST node named `Name`. |
| `lbl:A` | **Label:** Tags the captured node with the label `lbl`. |

---

## Example Usage

### 1. The Grammar

```text
//TODO
```

### 2. The Output AST

If the engine parses `x = 500`, it generates this labeled tree structure in memory:

```text
[AssignExpr]
 ├── target: [Variable] "x"
 └── value:  [Integer] "500"
```
