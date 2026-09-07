vim9script

import autoload 'autoflip/best_effort.vim' as best_effort

def Candidate(items: list<dict<any>>, identifier: string): dict<any>
  var found = items->copy()->filter((_, item) => item.identifier ==# identifier)
  return len(found) == 1 ? found[0] : {}
enddef

def TypeNode(candidate: dict<any>, kind: string, canonical: string): dict<any>
  return {
    role: 'type',
    kind: kind,
    range: candidate.semantic_type_range,
    arcana: "QualType '" .. canonical .. "'",
  }
enddef

def DirectAst(
    candidate: dict<any>,
    type_kind: string,
    declared_type: string,
    expression_kind: string,
    expression_type: string): dict<any>
  return {
    role: 'declaration',
    kind: 'Var',
    detail: candidate.identifier,
    range: candidate.range,
    children: [
      TypeNode(candidate, type_kind, declared_type),
      {
        role: 'expression',
        kind: expression_kind,
        range: candidate.initializer_range,
        arcana: expression_kind .. " '" .. expression_type .. "'",
      },
    ],
  }
enddef

def WrappedCallAst(candidate: dict<any>): dict<any>
  var canonical = 'eastl::optional<DynamicQuest>'
  return {
    role: 'declaration',
    kind: 'Var',
    detail: candidate.identifier,
    range: candidate.range,
    children: [
      TypeNode(candidate, 'Elaborated', canonical),
      {
        role: 'expression',
        kind: 'ExprWithCleanups',
        range: candidate.initializer_range,
        arcana: "ExprWithCleanups '" .. canonical .. "'",
        children: [{
          role: 'expression',
          kind: 'CXXBindTemporary',
          range: candidate.initializer_range,
          children: [{role: 'expression', kind: 'Call',
            range: candidate.initializer_range}],
        }],
      },
    ],
  }
enddef

new
setlocal filetype=cpp
setline(1, [
  'void f() {',
  '  State copied = state;',
  '  const Value * pointer = makePointer();',
  '  const Value& reference =',
  '      values[index];',
  '  eastl::optional<DynamicQuest> dynamicQuest =',
  '      DynamicQuest::make();',
  '  auto already = state;',
  '  Value&& rvalue = value;',
  '  Value converted = source;',
  '}',
])
var requested = {start: {line: 0, character: 0}, end: {line: 10, character: 1}}
var candidates = best_effort.Candidates(bufnr(), requested, 20)
assert_equal(['copied', 'pointer', 'reference', 'dynamicQuest', 'converted'],
  candidates->mapnew((_, item) => item.identifier))

var copied = Candidate(candidates, 'copied')
var pointer = Candidate(candidates, 'pointer')
var reference = Candidate(candidates, 'reference')
var dynamic_quest = Candidate(candidates, 'dynamicQuest')
var converted = Candidate(candidates, 'converted')
assert_equal('auto', copied.replacement)
assert_equal('const auto*', pointer.replacement)
assert_equal('const auto&', reference.replacement)
assert_equal('auto', dynamic_quest.replacement)
assert_equal(6, dynamic_quest.initializer_range.start.line)
assert_equal(6, dynamic_quest.initializer_range.end.line)

var copied_ast = DirectAst(copied, 'Enum', 'State', 'ImplicitCast', 'State')
copied_ast.children[1].detail = 'LValueToRValue'
copied_ast.children[1].children = [{role: 'expression', kind: 'DeclRef',
  range: copied.initializer_range}]
assert_equal('auto', best_effort.Validate(bufnr(), copied, copied_ast).replacement)

assert_equal('const auto*', best_effort.Validate(bufnr(), pointer,
  DirectAst(pointer, 'Pointer', 'const Value *', 'CXXMemberCall', 'const Value *')).replacement)
var reference_ast = DirectAst(reference, 'LValueReference', 'const Value &',
  'CXXOperatorCall', 'Value')
reference_ast.children[1].arcana = "CXXOperatorCallExpr 'Value' lvalue '[]'"
assert_equal('const auto&', best_effort.Validate(bufnr(), reference, reference_ast).replacement)
assert_equal('auto', best_effort.Validate(bufnr(), dynamic_quest,
  WrappedCallAst(dynamic_quest)).replacement)

var conversion = DirectAst(converted, 'Elaborated', 'Value', 'ImplicitCast', 'Value')
conversion.children[1].detail = 'IntegralCast'
conversion.children[1].children = [{role: 'expression', kind: 'DeclRef',
  range: converted.initializer_range}]
assert_equal({}, best_effort.Validate(bufnr(), converted, conversion))

var wrong_type = DirectAst(copied, 'Enum', 'State', 'Call', 'OtherState')
assert_equal({}, best_effort.Validate(bufnr(), copied, wrong_type))
bwipe!

new
setlocal filetype=cpp
setline(1, [
  'void f() {',
  '  const TeamId teamId = it.first;',
  '  const PlayerScore& bestPlayerScore = it.second;',
  '}',
])
var qualified_requested = {start: {line: 0, character: 0}, end: {line: 3, character: 1}}
var qualified_candidates = best_effort.Candidates(bufnr(), qualified_requested, 20)
var team_id = Candidate(qualified_candidates, 'teamId')
var best_player_score = Candidate(qualified_candidates, 'bestPlayerScore')

var team_id_ast = DirectAst(team_id, 'Qualified', 'const TeamId', 'ImplicitCast', 'fb::TeamId')
team_id_ast.children[0].children = [{
  role: 'type',
  kind: 'Enum',
  range: team_id.semantic_type_range,
  arcana: "QualType 'fb::TeamId'",
}]
team_id_ast.children[1].detail = 'LValueToRValue'
team_id_ast.children[1].children = [{
  role: 'expression',
  kind: 'Member',
  range: team_id.initializer_range,
  arcana: "MemberExpr 'const fb::TeamId' lvalue",
}]
assert_equal('const auto', best_effort.Validate(bufnr(), team_id, team_id_ast).replacement)

var best_player_score_ast = DirectAst(best_player_score, 'LValueReference',
  'const PlayerScore &', 'Member', 'const fb::diceOnline::PlayerScore')
best_player_score_ast.children[0].children = [{
  role: 'type',
  kind: 'Record',
  range: best_player_score.semantic_type_range,
  arcana: "QualType 'fb::diceOnline::PlayerScore'",
}]
best_player_score_ast.children[1].arcana = "MemberExpr 'const fb::diceOnline::PlayerScore' lvalue"
assert_equal('const auto&',
  best_effort.Validate(bufnr(), best_player_score, best_player_score_ast).replacement)
bwipe!
