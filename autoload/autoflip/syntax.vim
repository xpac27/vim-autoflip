vim9script

def MaskLine(text: string, scan: dict<any>): string
  var out: list<string> = []
  var byteidx = 0
  while byteidx < strlen(text)
    if scan.block_comment
      var end_comment = match(text, '\*/', byteidx)
      if end_comment >= 0
        add(out, repeat(' ', end_comment + 2 - byteidx))
        byteidx = end_comment + 2
        scan.block_comment = false
      else
        add(out, repeat(' ', strlen(text) - byteidx))
        break
      endif
    elseif scan.quote !=# ''
      var quote_start = byteidx
      while byteidx < strlen(text)
        var char = strpart(text, byteidx, 1)
        if scan.escape
          scan.escape = false
        elseif char ==# '\\'
          scan.escape = true
        elseif char ==# scan.quote
          scan.quote = ''
          byteidx += 1
          break
        endif
        byteidx += 1
      endwhile
      add(out, repeat(' ', byteidx - quote_start))
    else
      var special = match(text, '["''/]', byteidx)
      if special < 0
        add(out, strpart(text, byteidx))
        break
      endif
      if special > byteidx
        add(out, strpart(text, byteidx, special - byteidx))
        byteidx = special
        continue
      endif
      var two = strpart(text, byteidx, 2)
      var char = strpart(text, byteidx, 1)
      if two ==# '//'
        add(out, repeat(' ', strlen(text) - byteidx))
        break
      elseif two ==# '/*'
        add(out, '  ')
        byteidx += 2
        scan.block_comment = true
      elseif char ==# '"' || char ==# "'"
        add(out, ' ')
        byteidx += 1
        scan.quote = char
        scan.escape = false
      else
        add(out, char)
        byteidx += 1
      endif
    endif
  endwhile
  return join(out, '')
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

export def LocalDeclarationLines(
    bufnr: number,
    first: number,
    last: number): list<dict<any>>
  if first <= 0 || last < first
    return []
  endif
  var scan = {block_comment: false, quote: '', escape: false}
  var stack: list<string> = []
  var segment = ''
  var result: list<dict<any>> = []
  for current in range(1, last)
    var lines = getbufline(bufnr, current)
    if empty(lines)
      return []
    endif
    var masked = MaskLine(lines[0], scan)
    if current >= first
      add(result, {
        lnum: current,
        line: masked =~# '^\s*#' ? '' : masked,
        is_local: !empty(stack) && stack[-1] ==# 'local',
      })
    endif
    var idx = 0
    while idx < strlen(masked)
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
  return result
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
