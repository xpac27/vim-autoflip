vim9script

export def ModeComplete(lead: string, _line: string, _pos: number): list<string>
  return ['prefer-auto', 'show-deduced-types']->filter((_, mode) => mode =~# '^' .. escape(lead, '\\'))
enddef

export def PreferAutoLevelComplete(lead: string, _line: string, _pos: number): list<string>
  return ['clang-tidy', 'best-effort']->filter((_, level) => level =~# '^' .. escape(lead, '\\'))
enddef
