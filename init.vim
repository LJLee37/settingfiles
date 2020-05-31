set nocompatible
filetype off
filetype plugin on
call plug#begin('~/.config/nvim/plugged')
Plug 'neoclide/coc.nvim', {'tag': '*', 'do': './install.sh'}
Plug 'scrooloose/nerdtree'
Plug 'nanotech/jellybeans.vim'
Plug 'huawenyu/neogdb.vim'
Plug 'vim-airline/vim-airline'
Plug 'airblade/vim-gitgutter'
Plug 'octol/vim-cpp-enhanced-highlight'
Plug 'tpope/vim-fugitive'
Plug 'scrooloose/syntastic'
Plug 'zchee/deoplete-jedi'
Plug 'jiangmiao/auto-pairs'

call plug#end()

autocmd VimEnter * NERDTree

autocmd VimEnter * wincmd p
syntax on
set cindent
set number
let g:cpp_class_scope_highlight = 1
let g:cpp_member_variable_highlight = 1
let g:cpp_class_decl_highlight = 1
let g:cpp_posix_standard = 1
let g:cpp_experimental_simple_template_highlight = 1
let g:cpp_concepts_highlight = 1
"set ts=4 " Tab 너비
set shiftwidth=4 " 자동 인덴트할 때 너비
set hlsearch " 검색어 하이라이팅
set autowrite " 다른 파일로 넘어갈 때 자동 저장
"set sw=1 " 스크롤바 너비
set sts=4 "st select
colorscheme jellybeans
set showmatch " 일치하는 괄호 하이라이팅
set smartcase " 검색시 대소문자 구별
set smarttab
"set smartindent
"set softtabstop=4
"set tabstop=4
set list
set t_Co=256
nmap <F11> :NERDTreeToggle<CR>
set cino=:0g0
command! MakeTags !ctags -R .
set path+=**
set clipboard=unnamedplus
