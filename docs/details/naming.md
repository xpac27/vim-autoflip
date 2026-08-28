# Naming contract

## 2026-08-28 21:05 CEST - vim-autoflip namespaces

Use these exact forms:

| Surface | Form | Example |
| --- | --- | --- |
| Package/repository | `vim-autoflip` | installation directory |
| Commands/status/highlights | `AutoFlip` | `:AutoFlipEnable` |
| Globals/modules/state/properties | `autoflip` | `g:autoflip_mode` |
| Test environment | `AUTOFLIP` | `AUTOFLIP_VIM_LSP` |

The supported runtime contains only `plugin/autoflip.vim`,
`autoload/autoflip.vim`, and `autoload/autoflip/`. There are no forwarding
files, command aliases, global fallbacks, duplicated augroups, or alternate
property names.

The deterministic identity test asserts every public command and configuration
variable, both highlight groups, both property names, the load guard, and the
status prefix. A case-insensitive full-tree audit protects filenames and
content from obsolete identity fragments.
