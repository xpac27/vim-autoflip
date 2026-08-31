vim9script

def MaskLine(text: string, scan: dict<any>): string
  var out = ''
  var byteidx = 0
  while byteidx < strlen(text)
    var two = strpart(text, byteidx, 2)
    var char = strpart(text, byteidx, 1)
    if scan.block_comment
      if two ==# '*/'
        out ..= '  '
        byteidx += 2
        scan.block_comment = false
      else
        out ..= ' '
        byteidx += 1
      endif
    elseif scan.quote !=# ''
      out ..= ' '
      if scan.escape
        scan.escape = false
      elseif char ==# '\\'
        scan.escape = true
      elseif char ==# scan.quote
        scan.quote = ''
      endif
      byteidx += 1
    elseif two ==# '//'
      out ..= repeat(' ', strlen(text) - byteidx)
      break
    elseif two ==# '/*'
      out ..= '  '
      byteidx += 2
      scan.block_comment = true
    elseif char ==# '"' || char ==# "'"
      out ..= ' '
      scan.quote = char
      scan.escape = false
      byteidx += 1
    else
      out ..= char
      byteidx += 1
    endif
  endwhile
  return out
enddef

export def MaskedLine(bufnr: number, lnum: number): string
  var scan = {block_comment: false, quote: '', escape: false}
  var masked = ''
  for current in range(1, lnum)
    var lines = getbufline(bufnr, current)
    if empty(lines)
      return ''
    endif
    masked = MaskLine(lines[0], scan)
  endfor
  return masked
enddef

def BraceKind(segment: string, parent: string): string
  var clean = trim(segment)
  if clean =~# '\<\%(class\|struct\|union\|namespace\|enum\)\>'
    return 'nonlocal'
  endif
  if clean =~# ')\s*\%(\%(const\|volatile\|&&\|&\|noexcept\|override\|final\)\s*\)*$'
      || clean =~# ']\s*\%(([^)]*)\)\?\s*$'
    return 'local'
  endif
  return parent ==# 'local' ? 'local' : 'nonlocal'
enddef

export def IsLocal(bufnr: number, lnum: number, col: number): bool
  if lnum <= 0 || col <= 0
    return false
  endif
  var scan = {block_comment: false, quote: '', escape: false}
  var stack: list<string> = []
  var segment = ''
  for current in range(1, lnum)
    var lines = getbufline(bufnr, current)
    if empty(lines)
      return false
    endif
    var masked = MaskLine(lines[0], scan)
    var limit = current == lnum ? min([col - 1, strlen(masked)]) : strlen(masked)
    var idx = 0
    while idx < limit
      var char = strpart(masked, idx, 1)
      if char ==# '{'
        var parent = empty(stack) ? 'nonlocal' : stack[-1]
        add(stack, BraceKind(segment, parent))
        segment = ''
      elseif char ==# '}'
        if !empty(stack)
          remove(stack, -1)
        endif
        segment = ''
      elseif char ==# ';'
        segment = ''
      else
        segment ..= char
      endif
      idx += 1
    endwhile
    segment ..= ' '
  endfor
  return !empty(stack) && stack[-1] ==# 'local'
enddef

export def SafeDeclarationLine(bufnr: number, lnum: number): string
  var lines = getbufline(bufnr, lnum)
  if empty(lines)
    return ''
  endif
  var original = lines[0]
  var masked = MaskedLine(bufnr, lnum)
  if masked =~# '^\s*#'
    return ''
  endif
  return masked
enddef
