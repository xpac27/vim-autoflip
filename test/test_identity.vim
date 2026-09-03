vim9script

import autoload 'autoflip/render.vim' as render

for command in [
    'AutoFlipEnable',
    'AutoFlipDisable',
    'AutoFlipToggle',
    'AutoFlipMode',
    'AutoFlipPreferAutoLevel',
    'AutoFlipRefresh',
    'AutoFlipReveal',
    'AutoFlipStatus',
  ]
  assert_equal(2, exists(':' .. command), 'missing command :' .. command)
endfor

for variable in [
    'g:autoflip_enabled_by_default',
    'g:autoflip_mode',
    'g:autoflip_debounce_ms',
    'g:autoflip_reveal_on_insert',
    'g:autoflip_reveal_under_cursor',
    'g:autoflip_max_visible_lines',
    'g:autoflip_type_name_limit',
    'g:autoflip_prefer_auto_level',
  ]
  assert_true(exists(variable), 'missing configuration ' .. variable)
endfor

assert_true(exists('g:loaded_autoflip'))
assert_true(hlexists('AutoFlipAuto'))
assert_true(hlexists('AutoFlipDeducedType'))
assert_equal(['autoflip_auto', 'autoflip_deduced'], render.PropertyNames())
assert_match('^AutoFlip:', execute('AutoFlipStatus')->trim())
