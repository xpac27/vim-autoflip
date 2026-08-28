vim9script

import autoload 'autoflip/types.vim' as types

var view = types.NewView('prefer-auto', 2, 4, 12, 'const auto&')
assert_true(types.IsView(view))
assert_false(types.IsView({}))
assert_equal(['2:4', '3:1'], types.SortViews([
  extend(types.NewView('prefer-auto', 3, 1, 3, 'auto'), {label: '3:1'}),
  extend(types.NewView('prefer-auto', 2, 4, 3, 'auto'), {label: '2:4'}),
])->mapnew((_, item) => item.label))

