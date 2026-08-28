# Same-type copy validation

## 2026-08-28 20:29 CEST - Initial supported shape

The opt-in `same-type-copies` level extends conservative prefer-auto for this
single declaration family:

```cpp
Type target = source;
```

The declaration must be a local, one-line, single declarator without
cv/ref/pointer spelling. `Type`, `target`, and `source` must be spellings accepted by the
discovery grammar. Discovery only determines which bounded ranges are worth an
AST request; it never authorizes rendering.

clangd must return an AST node satisfying every condition:

- root `role=declaration`, `kind=Var`, and `detail=target`;
- root range exactly equals the discovered declaration without its semicolon;
- exactly one `role=type` child whose range equals the discovered type range;
- exactly one `role=expression` child with `kind=ImplicitCast` and
  `detail=LValueToRValue`;
- exactly one nested expression with `kind=DeclRef`, `detail=source`, and the
  same range as the implicit cast.

The source range is converted from UTF-16 to buffer bytes and becomes a normal
`TypeView` replacement of `auto`. Missing fields, extra semantic shapes,
different ranges, stale buffer generations, and conversions all reject the
candidate.

Examples deliberately rejected by the current grammar or AST validator:

```cpp
const State c = a;       // qualifier spelling is not synthesized
State& c = a;            // references are outside this level
long c = integer;        // AST reports an integral conversion
State c = make_state();  // call expression is not a direct copy
State a = x, b = y;      // multiple declarators are ambiguous
```
