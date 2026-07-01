" ============================================================
"  Catppuccin Macchiato — transparent Vim colorscheme
" ------------------------------------------------------------
"  Self-contained (no plugin manager). Mirrors the Neovim
"  catppuccin/nvim setup: Macchiato flavour, transparent
"  background so Ghostty's blur/transparency shows through,
"  italic comments + conditionals, bold keywords.
"
"  Requires a true-color terminal: `set termguicolors`.
" ============================================================

hi clear
if exists('syntax_on')
  syntax reset
endif
set background=dark
let g:colors_name = 'catppuccin_macchiato'

" ── Palette (official Macchiato) ────────────────────────────
let s:p = {
      \ 'rosewater': '#f4dbd6', 'flamingo': '#f0c6c6', 'pink': '#f5bde6',
      \ 'mauve':     '#c6a0f6', 'red':      '#ed8796', 'maroon': '#ee99a0',
      \ 'peach':     '#f5a97f', 'yellow':   '#eed49f', 'green':  '#a6da95',
      \ 'teal':      '#8bd5ca', 'sky':      '#91d7e3', 'sapphire':'#7dc4e4',
      \ 'blue':      '#8aadf4', 'lavender': '#b7bdf8', 'text':   '#cad3f5',
      \ 'subtext1':  '#b8c0e0', 'subtext0': '#a5adcb', 'overlay2':'#939ab7',
      \ 'overlay1':  '#8087a2', 'overlay0': '#6e738d', 'surface2':'#5b6078',
      \ 'surface1':  '#494d64', 'surface0': '#363a4f', 'base':   '#24273a',
      \ 'mantle':    '#1e2030', 'crust':    '#181926',
      \ }

" ── Highlight helper ────────────────────────────────────────
" bg == 'NONE' keeps the cell transparent (ctermbg=NONE too) so the
" terminal's own background / blur is what shows through.
function! s:hi(group, fg, bg, style) abort
  let l:c  = 'hi ' . a:group
  let l:c .= ' guifg=' . (a:fg ==# 'NONE' ? 'NONE' : s:p[a:fg])
  let l:c .= ' guibg=' . (a:bg ==# 'NONE' ? 'NONE' : s:p[a:bg])
  let l:c .= ' gui=' . a:style . ' cterm=' . a:style
  if a:bg ==# 'NONE'
    let l:c .= ' ctermbg=NONE'
  endif
  execute l:c
endfunction
command! -nargs=+ Hi call s:hi(<f-args>)

" ── Editor UI ───────────────────────────────────────────────
Hi Normal        text     NONE     NONE
Hi NormalNC      text     NONE     NONE
Hi NormalFloat   text     mantle   NONE
Hi FloatBorder   blue     mantle   NONE
Hi FloatTitle    blue     mantle   bold
Hi ColorColumn   NONE     surface0 NONE
Hi Cursor        base     rosewater NONE
Hi lCursor       base     rosewater NONE
Hi CursorLine    NONE     NONE     NONE
Hi CursorColumn  NONE     surface0 NONE
Hi CursorLineNr  lavender NONE     bold
Hi LineNr        surface2 NONE     NONE
Hi SignColumn    surface2 NONE     NONE
Hi FoldColumn    overlay0 NONE     NONE
Hi Folded        blue     surface0 NONE
Hi VertSplit     surface0 NONE     NONE
Hi WinSeparator  surface0 NONE     NONE
Hi EndOfBuffer   base     NONE     NONE
Hi MatchParen    peach    surface1 bold
Hi Visual        NONE     surface1 NONE
Hi VisualNOS     NONE     surface1 NONE
Hi Conceal       overlay0 NONE     NONE
Hi NonText       surface2 NONE     NONE
Hi SpecialKey    surface2 NONE     NONE
Hi Whitespace    surface1 NONE     NONE
Hi Directory     blue     NONE     NONE
Hi Title         blue     NONE     bold

" ── Search / selection ──────────────────────────────────────
Hi Search        base     yellow   NONE
Hi IncSearch     base     peach    NONE
Hi CurSearch     base     peach    NONE
Hi Substitute    base     peach    NONE
Hi QuickFixLine  NONE     surface1 NONE

" ── Popup menu (kept subtly solid so completion stays legible) ─
Hi Pmenu         subtext1 surface0 NONE
Hi PmenuSel      base     blue     bold
Hi PmenuSbar     NONE     surface1 NONE
Hi PmenuThumb    NONE     overlay0 NONE
Hi WildMenu      base     blue     NONE

" ── Status / tab line ───────────────────────────────────────
Hi StatusLine    text     surface0 NONE
Hi StatusLineNC  overlay0 mantle   NONE
Hi TabLine       overlay0 mantle   NONE
Hi TabLineSel    text     surface1 bold
Hi TabLineFill   NONE     NONE     NONE

" ── Messages ────────────────────────────────────────────────
Hi ModeMsg       green    NONE     bold
Hi MoreMsg       green    NONE     NONE
Hi Question      green    NONE     NONE
Hi ErrorMsg      red      NONE     bold
Hi WarningMsg    yellow   NONE     NONE

" ── Syntax ──────────────────────────────────────────────────
Hi Comment       overlay0 NONE     italic
Hi SpecialComment overlay0 NONE    italic
Hi Constant      peach    NONE     NONE
Hi String        green    NONE     NONE
Hi Character     green    NONE     NONE
Hi Number        peach    NONE     NONE
Hi Boolean       peach    NONE     NONE
Hi Float         peach    NONE     NONE
Hi Identifier    text     NONE     NONE
Hi Function      blue     NONE     NONE
Hi Statement     mauve    NONE     NONE
Hi Conditional   mauve    NONE     italic
Hi Repeat        mauve    NONE     NONE
Hi Label         sapphire NONE     NONE
Hi Operator      sky      NONE     NONE
Hi Keyword       mauve    NONE     bold
Hi Exception     mauve    NONE     NONE
Hi PreProc       pink     NONE     NONE
Hi Include       mauve    NONE     NONE
Hi Define        pink     NONE     NONE
Hi Macro         pink     NONE     NONE
Hi PreCondit     pink     NONE     NONE
Hi Type          yellow   NONE     NONE
Hi StorageClass  yellow   NONE     NONE
Hi Structure     yellow   NONE     NONE
Hi Typedef       yellow   NONE     NONE
Hi Special       pink     NONE     NONE
Hi SpecialChar   pink     NONE     NONE
Hi Tag           text     NONE     NONE
Hi Delimiter     overlay2 NONE     NONE
Hi Debug         red      NONE     NONE
Hi Underlined    text     NONE     underline
Hi Ignore        overlay0 NONE     NONE
Hi Error         red      NONE     bold
Hi Todo          yellow   surface1 bold

" ── Diff ────────────────────────────────────────────────────
Hi DiffAdd       green    surface0 NONE
Hi DiffChange    yellow   surface0 NONE
Hi DiffDelete    red      surface0 NONE
Hi DiffText      base     blue     NONE

" ── Spelling (needs guisp, so set outside the helper) ───────
hi SpellBad   gui=undercurl cterm=undercurl guisp=#ed8796
hi SpellCap   gui=undercurl cterm=undercurl guisp=#eed49f
hi SpellRare  gui=undercurl cterm=undercurl guisp=#a6da95
hi SpellLocal gui=undercurl cterm=undercurl guisp=#8bd5ca

" ── :terminal ANSI colours (Macchiato) ──────────────────────
if has('terminal')
  let g:terminal_ansi_colors = [
        \ s:p.surface1, s:p.red,  s:p.green, s:p.yellow,
        \ s:p.blue,     s:p.pink, s:p.teal,  s:p.subtext1,
        \ s:p.surface2, s:p.red,  s:p.green, s:p.yellow,
        \ s:p.blue,     s:p.pink, s:p.teal,  s:p.subtext0,
        \ ]
endif

delcommand Hi
