vim9script

import autoload 'autoflip/actions.vim' as actions
import autoload 'autoflip/range.vim' as rangeutil

var initialized = false
var diagnostics: dict<any> = {}

def TestAdapter(): dict<any>
  return get(g:, 'autoflip_test_lsp', {})
enddef

export def DependencyAvailable(): bool
  var test = TestAdapter()
  if !empty(test)
    return get(test, 'available', true)
  endif
  return exists('g:lsp_loaded') || !empty(globpath(&runtimepath, 'autoload/lsp.vim'))
enddef

def IsClangd(server: string): bool
  if server =~? 'clangd'
    return true
  endif
  var info = call('lsp#get_server_info', [server])
  return type(info) == v:t_dict && get(info, 'name', '') =~? 'clangd'
enddef

def Server(bufnr: number): string
  var test = TestAdapter()
  if !empty(test)
    return get(test, 'attached', false) ? get(test, 'server', 'clangd') : ''
  endif
  if !DependencyAvailable()
    return ''
  endif
  for server in call('lsp#get_allowed_servers', [bufnr])
    if type(server) == v:t_string && IsClangd(server)
        && call('lsp#is_server_running', [server])
      return server
    endif
  endfor
  return ''
enddef

def ProviderEnabled(provider: any): bool
  return (type(provider) == v:t_bool && provider)
      || (type(provider) == v:t_number && provider != 0)
      || type(provider) == v:t_dict
enddef

def Supports(bufnr: number, capability: string, test_key: string): bool
  var test = TestAdapter()
  if !empty(test)
    return get(test, test_key, false)
  endif
  var server = Server(bufnr)
  if empty(server)
    return false
  endif
  var capabilities = call('lsp#get_server_capabilities', [server])
  return type(capabilities) == v:t_dict
      && ProviderEnabled(get(capabilities, capability, false))
enddef

export def IsAttached(bufnr: number): bool
  return !empty(Server(bufnr))
enddef

export def SupportsCodeAction(bufnr: number): bool
  return Supports(bufnr, 'codeActionProvider', 'supports_code_actions')
enddef

export def SupportsInlayHints(bufnr: number): bool
  return Supports(bufnr, 'inlayHintProvider', 'supports_inlay_hints')
enddef

export def SupportsAst(bufnr: number): bool
  return Supports(bufnr, 'astProvider', 'supports_ast')
enddef

def DiagnosticKey(server: string, uri: string): string
  return server .. "\n" .. uri
enddef

def OnNotification(server: any, data: any)
  if type(server) != v:t_string || type(data) != v:t_dict
      || type(get(data, 'response', 0)) != v:t_dict

    return
  endif
  var response = data.response
  if get(response, 'method', '') !=# 'textDocument/publishDiagnostics'
      || type(get(response, 'params', 0)) != v:t_dict

    return
  endif
  var params = response.params
  if type(get(params, 'uri', 0)) != v:t_string
      || type(get(params, 'diagnostics', 0)) != v:t_list

    return
  endif
  diagnostics[DiagnosticKey(server, params.uri)] = deepcopy(params.diagnostics)
enddef

export def Initialize()
  if initialized || !DependencyAvailable() || !empty(TestAdapter())
    return
  endif
  call('lsp#register_notifications', ['autoflip', (server, data) => OnNotification(server, data)])
  initialized = true
enddef

def DiagnosticsFor(server: string, uri: string, requested: dict<any>): list<any>
  var result: list<any> = []
  for diagnostic in get(diagnostics, DiagnosticKey(server, uri), [])
    if type(diagnostic) == v:t_dict && actions.IsModernizeDiagnostic(diagnostic)
        && type(get(diagnostic, 'range', 0)) == v:t_dict
        && rangeutil.Contains(requested, diagnostic.range)
      add(result, deepcopy(diagnostic))
    endif
  endfor
  return result
enddef

def Deliver(Callback: func, payload: dict<any>, delay: number)
  if delay > 0
    timer_start(delay, (_) => Callback(payload))
  else
    Callback(payload)
  endif
enddef

def MockRequest(kind: string, bufnr: number, requested: dict<any>, Callback: func)
  var test = TestAdapter()
  if type(get(test, 'requests', 0)) != v:t_list
    test.requests = []
  endif
  add(test.requests, {kind: kind, bufnr: bufnr, range: deepcopy(requested)})
  var result = kind ==# 'code-actions' ? get(test, 'code_actions', []) : get(test, 'inlay_hints', [])
  Deliver(Callback, {ok: true, result: deepcopy(result), server: get(test, 'server', 'clangd')},
    get(test, 'delay_ms', 0))
enddef

def HandleResponse(server: string, Callback: func, data: any)
  if type(data) != v:t_dict || type(get(data, 'response', 0)) != v:t_dict
    Callback({ok: false, error: 'malformed vim-lsp response', result: [], server: server})
    return
  endif
  var response = data.response
  if has_key(response, 'error')
    Callback({ok: false, error: string(response.error), result: [], server: server})
    return
  endif
  Callback({ok: true, result: get(response, 'result', []), server: server})
enddef

export def RequestCodeActions(
    bufnr: number,
    requested: dict<any>,
    Callback: func): void
  if !empty(TestAdapter())
    MockRequest('code-actions', bufnr, requested, Callback)
    return
  endif
  var server = Server(bufnr)
  if empty(server)
    Callback({ok: false, error: 'clangd is not attached', result: [], server: ''})
    return
  endif
  var identifier = call('lsp#get_text_document_identifier', [bufnr])
  var uri = get(identifier, 'uri', '')
  call('lsp#send_request', [server, {
    method: 'textDocument/codeAction',
    bufnr: bufnr,
    params: {
      textDocument: identifier,
      range: requested,
      context: {
        diagnostics: DiagnosticsFor(server, uri, requested),
        only: ['quickfix'],
      },
    },
    on_notification: (data) => HandleResponse(server, Callback, data),
  }])
enddef

export def RequestInlayHints(
    bufnr: number,
    requested: dict<any>,
    Callback: func): void
  if !empty(TestAdapter())
    MockRequest('inlay-hints', bufnr, requested, Callback)
    return
  endif
  var server = Server(bufnr)
  if empty(server)
    Callback({ok: false, error: 'clangd is not attached', result: [], server: ''})
    return
  endif
  call('lsp#send_request', [server, {
    method: 'textDocument/inlayHint',
    bufnr: bufnr,
    params: {
      textDocument: call('lsp#get_text_document_identifier', [bufnr]),
      range: requested,
    },
    on_notification: (data) => HandleResponse(server, Callback, data),
  }])
enddef

def FinishAstRequest(
    server: string,
    candidate: dict<any>,
    pending: dict<any>,
    Callback: func,
    data: any)
  if type(data) == v:t_dict && type(get(data, 'response', 0)) == v:t_dict
      && !has_key(data.response, 'error') && type(get(data.response, 'result', 0)) == v:t_dict
    add(pending.result, {candidate: deepcopy(candidate), node: data.response.result})
  else
    pending.errors += 1
  endif
  pending.remaining -= 1
  if pending.remaining == 0
    Callback({ok: true, result: pending.result, errors: pending.errors, server: server})
  endif
enddef

def SendAstRequest(
    server: string,
    bufnr: number,
    identifier: dict<any>,
    candidate: dict<any>,
    pending: dict<any>,
    Callback: func)
  try
    call('lsp#send_request', [server, {
      method: 'textDocument/ast',
      bufnr: bufnr,
      params: {
        textDocument: identifier,
        range: candidate.range,
      },
      on_notification: (data) => FinishAstRequest(server, candidate, pending, Callback, data),
    }])
  catch
    FinishAstRequest(server, candidate, pending, Callback, {})
  endtry
enddef

export def RequestAsts(
    bufnr: number,
    candidates: list<dict<any>>,
    Callback: func): void
  var test = TestAdapter()
  if !empty(test)
    if type(get(test, 'requests', 0)) != v:t_list
      test.requests = []
    endif
    add(test.requests, {kind: 'asts', bufnr: bufnr, candidates: deepcopy(candidates)})
    Deliver(Callback, {ok: true, result: deepcopy(get(test, 'ast_responses', [])),
      errors: 0, server: get(test, 'server', 'clangd')}, get(test, 'delay_ms', 0))
    return
  endif
  var server = Server(bufnr)
  if empty(server)
    Callback({ok: false, error: 'clangd is not attached', result: [], server: ''})
    return
  endif
  if empty(candidates)
    Callback({ok: true, result: [], errors: 0, server: server})
    return
  endif
  var identifier = call('lsp#get_text_document_identifier', [bufnr])
  var pending = {remaining: len(candidates), result: [], errors: 0}
  for candidate in candidates
    SendAstRequest(server, bufnr, identifier, candidate, pending, Callback)
  endfor
enddef

def FinishPreferAutoPart(
    key: string,
    pending: dict<any>,
    Callback: func,
    response: dict<any>)
  pending[key] = response
  pending.remaining -= 1
  if pending.remaining != 0
    return
  endif
  if !get(pending.actions, 'ok', false)
    Callback(pending.actions)
    return
  endif
  if !get(pending.asts, 'ok', false)
    Callback(pending.asts)
    return
  endif
  Callback({
    ok: true,
    result: {
      actions: get(pending.actions, 'result', []),
      asts: get(pending.asts, 'result', []),
      ast_errors: get(pending.asts, 'errors', 0),
    },
    server: get(pending.actions, 'server', ''),
  })
enddef

export def RequestPreferAuto(
    bufnr: number,
    requested: dict<any>,
    candidates: list<dict<any>>,
    Callback: func): void
  var pending = {remaining: 2, actions: {}, asts: {}}
  RequestCodeActions(bufnr, requested,
    (response) => FinishPreferAutoPart('actions', pending, Callback, response))
  RequestAsts(bufnr, candidates,
    (response) => FinishPreferAutoPart('asts', pending, Callback, response))
enddef

export def CurrentUri(bufnr: number): string
  var test = TestAdapter()
  if !empty(test)
    return get(test, 'uri', 'file:///autoflip-test.cpp')
  endif
  if !DependencyAvailable()
    return ''
  endif
  return get(call('lsp#get_text_document_identifier', [bufnr]), 'uri', '')
enddef

export def ResetForTest()
  initialized = false
  diagnostics = {}
enddef
