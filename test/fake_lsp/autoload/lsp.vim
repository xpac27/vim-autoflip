if exists('g:autoloaded_autoflip_fake_lsp')
  finish
endif
let g:autoloaded_autoflip_fake_lsp = 1

function! lsp#get_allowed_servers(bufnr) abort
  return ['clangd']
endfunction

function! lsp#get_server_info(server) abort
  return {'name': a:server}
endfunction

function! lsp#is_server_running(server) abort
  return 1
endfunction

function! lsp#get_server_capabilities(server) abort
  return {'codeActionProvider': v:true, 'inlayHintProvider': {}, 'astProvider': v:true}
endfunction

function! lsp#get_text_document_identifier(bufnr) abort
  return {'uri': 'file:///fake.cpp'}
endfunction

function! lsp#register_notifications(name, Callback) abort
  let g:AutoflipFakeNotificationCallback = a:Callback
endfunction

function! lsp#send_request(server, request) abort
  let g:autoflip_fake_request = deepcopy(a:request)
  call a:request.on_notification({
        \ 'response': {'result': get(g:, 'autoflip_fake_result', [])},
        \ })
endfunction
