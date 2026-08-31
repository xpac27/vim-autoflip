vim9script

import autoload 'autoflip/copies.vim' as copies

def LspRange(line: number, start: number, finish: number): dict<any>
  return {start: {line: line, character: start}, end: {line: line, character: finish}}
enddef

def CopyAst(
    line: number,
    type_start: number,
    type_end: number,
    declaration_end: number,
    identifier: string,
    initializer_start: number,
    initializer: string,
    cast_kind: string = 'LValueToRValue'): dict<any>
  var expression_range = LspRange(line, initializer_start, initializer_start + strlen(initializer))
  return {
    role: 'declaration',
    kind: 'Var',
    detail: identifier,
    range: LspRange(line, type_start, declaration_end),
    children: [
      {role: 'type', kind: 'Enum', detail: 'State', range: LspRange(line, type_start, type_end)},
      {
        role: 'expression',
        kind: 'ImplicitCast',
        detail: cast_kind,
        range: expression_range,
        children: [{role: 'expression', kind: 'DeclRef', detail: initializer,
          range: expression_range}],
      },
    ],
  }
enddef

def Candidate(items: list<dict<any>>, identifier: string): dict<any>
  var found = items->copy()->filter((_, item) => item.identifier ==# identifier)
  return len(found) == 1 ? found[0] : {}
enddef

def CandidateExpressionRange(candidate: dict<any>): dict<any>
  var line = getline(candidate.lnum)
  var start = match(line, '=\s*\zs')
  var finish = start + strlen(candidate.initializer)
  return LspRange(candidate.lnum - 1, start, finish)
enddef

def ConstructAst(candidate: dict<any>): dict<any>
  var expression = CandidateExpressionRange(candidate)
  return {
    role: 'declaration',
    kind: 'Var',
    detail: candidate.identifier,
    range: candidate.range,
    children: [
      {role: 'type', kind: 'Record', detail: 'Container', range: candidate.type_range},
      {
        role: 'expression',
        kind: 'CXXConstruct',
        range: expression,
        children: [{
          role: 'expression',
          kind: 'ImplicitCast',
          detail: 'NoOp',
          range: expression,
          children: [{role: 'expression', kind: 'DeclRef', detail: candidate.initializer,
            range: expression}],
        }],
      },
    ],
  }
enddef

def ReferenceSubscriptAst(candidate: dict<any>, lvalue: bool = true): dict<any>
  return {
    role: 'declaration',
    kind: 'Var',
    detail: candidate.identifier,
    range: candidate.range,
    children: [
      {role: 'type', kind: 'LValueReference', range: candidate.type_range},
      {
        role: 'expression',
        kind: 'CXXOperatorCall',
        arcana: lvalue ? "CXXOperatorCallExpr 'Value' lvalue '[]'" : "CXXOperatorCallExpr 'Value' '[]'",
        range: candidate.initializer_range,
      },
    ],
  }
enddef

def PointerAst(candidate: dict<any>): dict<any>
  return {
    role: 'declaration',
    kind: 'Var',
    detail: candidate.identifier,
    range: candidate.range,
    children: [
      {role: 'type', kind: 'Pointer', detail: 'Value *', range: candidate.type_range},
      {
        role: 'expression',
        kind: 'ImplicitCast',
        detail: 'LValueToRValue',
        range: candidate.initializer_range,
        children: [{role: 'expression', kind: 'DeclRef', detail: candidate.initializer,
          range: candidate.initializer_range}],
      },
    ],
  }
enddef

def CallAst(candidate: dict<any>): dict<any>
  var type_kind = candidate.replacement ==# 'const auto' ? 'Qualified' : 'Typedef'
  var type_detail = candidate.replacement ==# 'const auto' ? 'const' : 'Count'
  return {
    role: 'declaration',
    kind: 'Var',
    detail: candidate.identifier,
    range: candidate.range,
    children: [
      {role: 'type', kind: type_kind, detail: type_detail, range: candidate.type_range},
      {role: 'expression', kind: 'Call', range: candidate.initializer_range},
    ],
  }
enddef

def WrappedMemberCallAst(candidate: dict<any>): dict<any>
  return {
    role: 'declaration',
    kind: 'Var',
    detail: candidate.identifier,
    range: candidate.range,
    children: [
      {role: 'type', kind: 'Qualified', detail: 'const', range: candidate.type_range},
      {
        role: 'expression',
        kind: 'ExprWithCleanups',
        range: candidate.initializer_range,
        children: [{
          role: 'expression',
          kind: 'ImplicitCast',
          detail: 'NoOp',
          range: candidate.initializer_range,
          children: [{
            role: 'expression',
            kind: 'CXXBindTemporary',
            range: candidate.initializer_range,
            children: [{role: 'expression', kind: 'CXXMemberCall',
              range: candidate.initializer_range}],
          }],
        }],
      },
    ],
  }
enddef

new
setlocal filetype=cpp
setline(1, [
  'class Base { public: virtual void f() const = 0; };',
  'class Derived : Base {',
  '  void f() const override {',
  '    State c = a;',
  '    Transition d=b;',
  '    long converted = integer;',
  '    const State fixed = a;',
  '    State made = factory();',
  '    State one = a, two = b;',
  '    Container next = current;',
  '    Value& reference = values[index];',
  '    Value* pointer = source;',
  '    Value& returned = factory();',
  '    Value* null = nullptr;',
  '    Value&& rvalue = values[index];',
  '    const Count hash = hashValue();',
  '    Count generated = makeCount();',
  '    const Holder held =',
  '      factory.makeHolder();',
  '  }',
  '};',
  'State field = other;',
])
var requested = {start: {line: 0, character: 0}, end: {line: 19, character: 20}}
var candidates = copies.Candidates(bufnr(), requested, 20)
assert_equal(4, len(candidates))
assert_equal(['c', 'd', 'converted', 'next'], candidates->mapnew((_, item) => item.identifier))
assert_equal(LspRange(3, 4, 15), candidates[0].range)
assert_equal(LspRange(3, 4, 9), candidates[0].type_range)

var state_ast = CopyAst(3, 4, 9, 15, 'c', 14, 'a')
var transition_ast = CopyAst(4, 4, 14, 18, 'd', 17, 'b')
var views = copies.Normalize(bufnr(), [
  {candidate: candidates[0], node: state_ast},
  {candidate: candidates[1], node: transition_ast},
])
assert_equal(2, len(views))
assert_equal([5, 5], views->mapnew((_, view) => view.col))
assert_equal([5, 10], views->mapnew((_, view) => view.length))
assert_equal(['auto', 'auto'], views->mapnew((_, view) => view.replacement))

# An AST conversion, malformed range, wrong declaration, or non-reference
# initializer cannot authorize a substitution.
var conversion = CopyAst(5, 4, 8, 28, 'converted', 21, 'integer', 'IntegralCast')
assert_equal({}, copies.Validate(bufnr(), candidates[2], conversion))
var wrong_range = deepcopy(state_ast)
wrong_range.children[0].range.end.character = 8
assert_equal({}, copies.Validate(bufnr(), candidates[0], wrong_range))
var wrong_name = deepcopy(state_ast)
wrong_name.detail = 'other'
assert_equal({}, copies.Validate(bufnr(), candidates[0], wrong_name))
var call = deepcopy(state_ast)
call.children[1].kind = 'Call'
assert_equal({}, copies.Validate(bufnr(), candidates[0], call))

assert_equal(1, len(copies.Candidates(bufnr(), requested, 1)))
assert_equal([], copies.Candidates(bufnr(), requested, 0))

var ast_proven = copies.AstProvenCandidates(bufnr(), requested, 20)
assert_equal(['c', 'd', 'converted', 'next', 'reference', 'pointer', 'returned', 'null', 'made', 'hash', 'generated', 'held'],
  ast_proven->mapnew((_, item) => item.identifier))
var next = Candidate(ast_proven, 'next')
var reference = Candidate(ast_proven, 'reference')
var pointer = Candidate(ast_proven, 'pointer')
var hash = Candidate(ast_proven, 'hash')
var generated = Candidate(ast_proven, 'generated')
var held = Candidate(ast_proven, 'held')
assert_equal({}, Candidate(ast_proven, 'rvalue'))
assert_equal('auto&', reference.replacement)
assert_equal('auto*', pointer.replacement)
assert_equal('const auto', hash.replacement)
assert_equal('auto', generated.replacement)
assert_equal('const auto', held.replacement)

var ast_proven_views = copies.NormalizeAstProven(bufnr(), [
  {candidate: next, node: ConstructAst(next)},
  {candidate: reference, node: ReferenceSubscriptAst(reference)},
  {candidate: pointer, node: PointerAst(pointer)},
  {candidate: hash, node: CallAst(hash)},
  {candidate: generated, node: CallAst(generated)},
])
assert_equal(['auto', 'auto&', 'auto*', 'const auto', 'auto'],
  ast_proven_views->mapnew((_, view) => view.replacement))

assert_equal({}, copies.ValidateAstProven(bufnr(), reference, ReferenceSubscriptAst(reference, false)))
var call_ast = ReferenceSubscriptAst(reference)
call_ast.children[1].kind = 'Call'
assert_equal({}, copies.ValidateAstProven(bufnr(), reference, call_ast))
var null_ast = PointerAst(pointer)
null_ast.children[1].kind = 'ImplicitCast'
null_ast.children[1].detail = 'NullToPointer'
assert_equal({}, copies.ValidateAstProven(bufnr(), pointer, null_ast))
var conversion_call = CallAst(hash)
conversion_call.children[1].kind = 'ImplicitCast'
conversion_call.children[1].detail = 'ConstructorConversion'
assert_equal({}, copies.ValidateAstProven(bufnr(), hash, conversion_call))
assert_equal('const auto', copies.ValidateAstProven(bufnr(), held, WrappedMemberCallAst(held)).replacement)
bwipe!
