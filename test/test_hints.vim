vim9script

import autoload 'autoveil/hints.vim' as hints

def Hint(line: number, character: number, label: any, kind: number = 1): dict<any>
  return {position: {line: line, character: character}, label: label, kind: kind}
enddef

new
setlocal filetype=cpp
setline(1, ['void f() {',
  '  auto count = values.size();',
  '  const auto& record = records.front();',
  '}',
  'auto field = factory();',
  'void g() { auto [x, y] = pair; }'])
var requested = {start: {line: 0, character: 0}, end: {line: 5, character: 40}}
var views = hints.Normalize(bufnr(), requested, [
  Hint(1, 12, ': unsigned long'),
  Hint(2, 20, [{value: ': '}, {value: 'const Record&'}]),
], 80)
assert_equal(2, len(views))
assert_equal(['unsigned long', 'const Record&'], views->mapnew((_, view) => view.replacement))
assert_equal([3, 3], views->mapnew((_, view) => view.col))
assert_equal([4, 11], views->mapnew((_, view) => view.length))

assert_equal([], hints.Normalize(bufnr(), requested, [Hint(4, 10, ': Thing')], 80))
assert_equal([], hints.Normalize(bufnr(), requested, [Hint(1, 12, ': int', 2)], 80))
assert_equal([], hints.Normalize(bufnr(), requested, [Hint(5, 24, ': Pair')], 80))
assert_equal('', hints.TypeLabel(': std::vector<int, std::allocator<int>>', 10))
assert_equal('', hints.TypeLabel(": Type\nInjected", 80))
assert_equal('', hints.TypeLabel(': auto', 80))
assert_equal([], hints.Normalize(bufnr(), requested,
  [Hint(1, 12, ': int'), Hint(1, 12, ': long')], 80))
bwipe!
