vim9script

import autoload 'autoveil/range.vim' as rangeutil

new
setline(1, 'a😀z')
assert_equal(1, rangeutil.ByteCol(bufnr(), 0, 0))
assert_equal(2, rangeutil.ByteCol(bufnr(), 0, 1))
assert_equal(-1, rangeutil.ByteCol(bufnr(), 0, 2))
assert_equal(6, rangeutil.ByteCol(bufnr(), 0, 3))
assert_equal(7, rangeutil.ByteCol(bufnr(), 0, 4))
assert_equal({lnum: 1, col: 2, end_col: 6, length: 4}, rangeutil.ByteRange(bufnr(), {
  start: {line: 0, character: 1}, end: {line: 0, character: 3}}))
bwipe!

