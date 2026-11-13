"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""         >
"
"               ██╗   ██╗██╗███╗   ███╗██████╗  ██████╗
"               ██║   ██║██║████╗ ████║██╔══██╗██╔════╝
"               ██║   ██║██║██╔████╔██║██████╔╝██║
"               ╚██╗ ██╔╝██║██║╚██╔╝██║██╔══██╗██║
"                ╚████╔╝ ██║██║ ╚═╝ ██║██║  ██║╚██████╗
"                 ╚═══╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Disable compatibility with vi which can cause unexpected issues.
set nocompatible

" Space is the leader key (kickstart / ThePrimeagen); must be set before any <leader> mapping.
let mapleader = " "
let maplocalleader = " "

" Enable type file detection. Vim will be able to try to detect the type of file.
filetype on

" Enable plugins and load plugin for the detected file type.
filetype plugin on

" Load an indent file for the detected file type.
filetype indent on

" Turn syntax highlighting on.
syntax on

" Add numbers to each line on the left-hand side.
set number

" Highlight cursor line underneath the cursor horizontally.
set cursorline

" Set shift width to 4 spaces.
set shiftwidth=4

" Set tab width to 4 columns.
set tabstop=4

" Backspace deletes a whole indent level, like VS Code.
set softtabstop=-1

" Keep the previous line's indent on a new line.
set autoindent

" Use space characters instead of tabs.
set expandtab

" Do not let cursor scroll below or above N number of lines when scrolling.
set scrolloff=10

" Wrap long lines on screen, like VS Code's editor.wordWrap.
set wrap

" Wrap at word boundaries, not mid-word, and keep the indent on wrapped lines.
set linebreak
set breakindent

" While searching though a file incrementally highlight matching characters as you type.
set incsearch

" Ignore capital letters during search.
set ignorecase

" Override the ignorecase option if searching for capital letters. This will
" allow you to search specifically for capital letters
set smartcase

" Show partial command you type in the last line of the screen.
set showcmd

" Show matching words during a search.
set showmatch

" Use highlighting when doing a search.
set hlsearch

" Set the commands to save in history default number is 20.
set history=1000

" Enable auto completion menu after pressing TAB.
set wildmenu

" Make wildmenu behave like similar to Bash completion.
set wildmode=list:longest

" There are certain files that we would never want to edit with Vim.
" Wildmenu will ignore files with these extensions.
set wildignore=*.docx,*.jpg,*.png,*.gif,*.pdf,*.pyc,*.exe,*.flv,*.img,*.xlsx

" Change color scheme to something nice?
colo molokai

" EVERYDAY DEFAULTS ------------------------------------------------------ {{{
" A custom vimrc stops Vim loading defaults.vim, so these have to be set by hand
" (Neovim already defaults to most of them).

" Backspace over auto-indent, line breaks and the start of insert.
set backspace=indent,eol,start

" No lag after pressing Esc.
set ttimeout
set ttimeoutlen=50

" Switch buffers without saving first.
set hidden

" Show the cursor position in the bottom right.
set ruler

" From kickstart.nvim: always show the sign column (no text jumping when git/ALE
" markers appear), shorter wait for multi-key mappings, show tabs and trailing
" spaces, ask instead of failing on unsaved changes.
set signcolumn=yes
set timeoutlen=300
set list
set listchars=tab:»\ ,trail:·,nbsp:␣
set confirm
if has('nvim')
    " Preview :s substitutions live in a split.
    set inccommand=split
endif

" The airline status bar needs a status line on every window, and shows the mode itself.
set laststatus=2
set noshowmode

" Click to move the cursor, scroll, and drag split borders.
set mouse=a

" Use the system clipboard for yank/paste, only where this build/machine has one.
if has('clipboard')
    set clipboard=unnamedplus
endif

" Keep swap and undo files out of project folders. Vim and Neovim file formats
" are incompatible, so Vim gets its own folders and Neovim keeps its defaults
" (~/.local/state/nvim/{swap,undo}).
if !has('nvim')
    for s:dir in ['swap', 'undo']
        if !isdirectory(expand('~/.local/state/vim/' . s:dir))
            call mkdir(expand('~/.local/state/vim/' . s:dir), 'p', 0700)
        endif
    endfor
    set directory=~/.local/state/vim/swap//
    set undodir=~/.local/state/vim/undo//
endif

" New splits open to the right and below, like VS Code.
set splitright
set splitbelow

" Git gutter markers and other idle events update after 0.3s instead of 4s.
set updatetime=300

" Follow a project's .editorconfig (built into Neovim, bundled-but-optional in Vim).
if !has('nvim')
    silent! packadd! editorconfig
endif

" Reopen files at the last cursor position.
augroup restore_cursor
    autocmd!
    autocmd BufReadPost * if line("'\"") >= 1 && line("'\"") <= line("$") && &ft !~# 'commit' | exe "normal! g`\"" | endif
augroup END

" }}}

" PLUGINS ---------------------------------------------------------------- {{{
" Plugins are not in git; ~/Scripts/setupVim/setupVim.sh (or the first launch) installs them.

if filereadable(expand('~/.vim/autoload/plug.vim'))
    call plug#begin('~/.vim/plugged')

      Plug 'dense-analysis/ale'
      Plug 'preservim/nerdtree'
      Plug 'mattn/emmet-vim'
      Plug 'airblade/vim-gitgutter'
      Plug 'tpope/vim-commentary'
      Plug 'vim-airline/vim-airline'
      Plug 'godlygeek/tabular'
      Plug 'fatih/vim-go'
      Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
      Plug 'junegunn/fzf.vim'
      Plug 'tpope/vim-fugitive'
      Plug 'tpope/vim-surround'
      Plug 'tpope/vim-sleuth'
      " sudo save; plain `:w !sudo tee` can't prompt for a password in Neovim
      Plug 'lambdalisue/suda.vim'
      if has('nvim')
          Plug 'tjdevries/colorbuddy.nvim'
          Plug '2nthony/vitesse.nvim'
      endif

    call plug#end()

    " Vitesse to match VS Code's Vitesse Black; the port is dark-only, so force the black background.
    if has('nvim') && isdirectory(expand('~/.vim/plugged/vitesse.nvim'))
        set termguicolors
        lua pcall(function() require('vitesse').setup({ transparent_background = false }) end)
        silent! colorscheme vitesse
        highlight Normal guibg=#000000
    endif

    " Format on save with the same tools and options as VS Code, each only if installed here.
    let g:ale_fix_on_save = 1
    let g:ale_python_isort_options = '--profile black'
    let g:ale_javascript_prettier_options = '--tab-width 4 --trailing-comma all'
    let s:fixers = {
        \ 'python': ['isort', 'black'],
        \ 'javascript': ['prettier'], 'javascriptreact': ['prettier'],
        \ 'typescript': ['prettier'], 'typescriptreact': ['prettier'],
        \ 'json': ['prettier'], 'jsonc': ['prettier'], 'html': ['prettier'],
        \ 'css': ['prettier'], 'scss': ['prettier'], 'markdown': ['prettier'], 'yaml': ['prettier'],
        \ 'sh': ['shfmt'], 'c': ['clang-format'], 'cpp': ['clang-format'], 'dart': ['dart-format'],
        \ }
    let s:fixer_exe = {'isort': 'isort', 'black': 'black', 'prettier': 'prettier',
        \ 'shfmt': 'shfmt', 'clang-format': 'clang-format', 'dart-format': 'dart'}
    let g:ale_fixers = {}
    for [s:ft, s:list] in items(s:fixers)
        let s:found = filter(copy(s:list), 'executable(s:fixer_exe[v:val])')
        if !empty(s:found)
            let g:ale_fixers[s:ft] = s:found
        endif
    endfor
    " Go is formatted on save by vim-go (gofmt), like the VS Code Go extension.

    " Install any missing plugins on startup, e.g. right after a git pull on a new machine.
    augroup plug_autoinstall
        autocmd!
        autocmd VimEnter * if len(filter(values(g:plugs), '!isdirectory(v:val.dir)'))
            \| PlugInstall --sync | source $MYVIMRC
            \| endif
    augroup END
endif

" }}}

" MAPPINGS --------------------------------------------------------------- {{{
" Core keys from kickstart.nvim (github.com/nvim-lua/kickstart.nvim) and
" ThePrimeagen's remaps (github.com/ThePrimeagen/init.lua), ported to Vimscript so
" Vim and Neovim behave the same. Telescope searches are mapped to fzf.vim.
" Space is the leader (set at the top of this file).

" --- kickstart: basics ---
" Esc clears search highlighting (Esc Esc in Vim, where a bare <Esc> map garbles terminal key codes).
if has('nvim')
    nnoremap <Esc> <cmd>nohlsearch<CR>
else
    nnoremap <Esc><Esc> <cmd>nohlsearch<CR>
endif
" Diagnostics list for the current file (ALE errors/warnings).
nnoremap <leader>q <cmd>lopen<CR>
" Leave the built-in terminal with Esc Esc.
if has('nvim') || has('terminal')
    tnoremap <Esc><Esc> <C-\><C-n>
endif
" Ctrl+h/j/k/l moves between splits.
nnoremap <C-h> <C-w><C-h>
nnoremap <C-l> <C-w><C-l>
nnoremap <C-j> <C-w><C-j>
nnoremap <C-k> <C-w><C-k>

" --- kickstart: search (Telescope keys, fzf.vim commands) ---
nnoremap <leader>sf <cmd>Files<CR>
nnoremap <leader>sh <cmd>Helptags<CR>
nnoremap <leader>sk <cmd>Maps<CR>
nnoremap <leader>sc <cmd>Commands<CR>
nnoremap <leader>s. <cmd>History<CR>
nnoremap <leader><leader> <cmd>Buffers<CR>
nnoremap <leader>/ <cmd>BLines<CR>
if executable('rg')
    nnoremap <leader>sg <cmd>Rg<CR>
    nnoremap <leader>sw :Rg <C-r><C-w><CR>
endif
" Format the file now (format-on-save does this automatically).
nnoremap <leader>f <cmd>ALEFix<CR>

" --- ThePrimeagen ---
" File explorer: netrw (built in) or the NERDTree sidebar.
nnoremap <leader>pv <cmd>Explore<CR>
nnoremap <leader>e <cmd>NERDTreeToggle<CR>
" Move selected lines up/down, re-indenting as they go.
xnoremap J :m '>+1<CR>gv=gv
xnoremap K :m '<-2<CR>gv=gv
" Join lines without the cursor jumping.
nnoremap J mzJ`z
" Keep the cursor centred when half-paging and stepping through search results.
nnoremap <C-d> <C-d>zz
nnoremap <C-u> <C-u>zz
nnoremap n nzzzv
nnoremap N Nzzzv
" Paste over a selection without losing what you copied.
xnoremap <leader>p "_dP
" Yank to the system clipboard explicitly.
nnoremap <leader>y "+y
xnoremap <leader>y "+y
nnoremap <leader>Y "+Y
" Delete without overwriting what you copied.
nnoremap <leader>d "_d
xnoremap <leader>d "_d
" Q (Ex mode) is never wanted.
nnoremap Q <nop>
" Replace every occurrence of the word under the cursor ("s" is taken by search).
nnoremap <leader>r :%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>
" Make the current file executable.
nnoremap <silent> <leader>x <cmd>!chmod +x %<CR>

" --- VS Code habits ---
" Ctrl+P opens a file, like VS Code's Quick Open.
nnoremap <C-p> <cmd>Files<CR>
" Y yanks to end of line in Vim too (Neovim's default).
nnoremap Y y$
" :w!! saves a file you opened without sudo.
cnoremap w!! SudaWrite

" Have nerdtree ignore certain files and directories.
let NERDTreeIgnore=['\.git$', '\.jpg$', '\.mp4$', '\.ogg$', '\.iso$', '\.pdf$', '\.pyc$', '\.odt$', '\.png$', '\.gif$', '\.db$']

" }}}

" VIMSCRIPT -------------------------------------------------------------- {{{

" Enable the marker method of folding.
augroup filetype_vim
    autocmd!
    autocmd FileType vim setlocal foldmethod=marker
augroup END

" Per-language indentation, matching VS Code (4 spaces unless listed here).
augroup indent_overrides
    autocmd!
    autocmd FileType dart,yaml,yaml.docker-compose,yaml.ansible,ansible setlocal tabstop=2 shiftwidth=2 expandtab
    " gofmt and Makefiles require real tabs
    autocmd FileType go,make setlocal noexpandtab tabstop=4 shiftwidth=4
augroup END

" Trim trailing whitespace on save, like files.trimTrailingWhitespace.
augroup trim_whitespace
    autocmd!
    autocmd BufWritePre * if &filetype !=# 'markdown' && !&binary | let s:v = winsaveview() | keeppatterns %s/\s\+$//e | call winrestview(s:v) | endif
augroup END

" Save all files when focus leaves Vim, like files.autoSave onFocusChange.
augroup autosave_focus
    autocmd!
    autocmd FocusLost * silent! wall
augroup END

" Always end files with a newline and use LF, like files.insertFinalNewline.
set fixendofline
set fileformats=unix,dos

" If Vim version is equal to or greater than 7.3 enable undofile.
" This allows you to undo changes to a file even after saving it.
if version >= 703
    set undofile
    set undoreload=10000
endif

" You can split a window into sections by typing `:split` or `:vsplit`.
" Display cursorline ONLY in active window.
augroup cursor_off
    autocmd!
    autocmd WinLeave * set nocursorline
    autocmd WinEnter * set cursorline
augroup END

" }}}
