#!/usr/bin/env bash
set -u

if ! command -v clangd >/dev/null 2>&1; then
  echo 'SKIP: clangd is not installed'
  exit 0
fi

if [[ -z "${AUTOFLIP_VIM_LSP:-}" || ! -f "${AUTOFLIP_VIM_LSP}/plugin/lsp.vim" ]]; then
  echo 'SKIP: set AUTOFLIP_VIM_LSP to a vim-lsp checkout'
  exit 0
fi

AUTOFLIP_TEST_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export AUTOFLIP_TEST_ROOT
exec vim -Nu NONE -U NONE -i NONE -n -es -S "$AUTOFLIP_TEST_ROOT/test/integration_clangd.vim"

