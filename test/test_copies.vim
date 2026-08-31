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
  '  }',
  '};',
  'State field = other;',
])
var requested = {start: {line: 0, character: 0}, end: {line: 11, character: 20}}
var candidates = copies.Candidates(bufnr(), requested, 20)
assert_equal(3, len(candidates))
assert_equal(['c', 'd', 'converted'], candidates->mapnew((_, item) => item.identifier))
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
bwipe!
