set nocompatible
filetype off
call plug#begin('~/.config/nvim/plugged')
" Use release branch
"Plug 'neoclide/coc.nvim', {'branch': 'release'}
" Or latest tag
"Plug 'neoclide/coc.nvim', {'tag': '*', 'branch': 'release'}
" Or build from source code by use yarn: https://yarnpkg.com
"Plug 'neoclide/coc.nvim', {'do': 'yarn install --frozen-lockfile'}
Plug 'neoclide/coc.nvim', {'tag': '*', 'do': './install.sh'}
Plug 'scrooloose/nerdtree'
Plug 'nanotech/jellybeans.vim'
Plug 'vim-airline/vim-airline'
Plug 'airblade/vim-gitgutter'
Plug 'octol/vim-cpp-enhanced-highlight'
Plug 'tpope/vim-fugitive'
Plug 'scrooloose/syntastic'
Plug 'preservim/tagbar'
Plug 'nathanaelkane/vim-indent-guides'
Plug 'vim-airline/vim-airline-themes'
Plug 'blueyed/vim-diminactive'
Plug 'aurieh/discord.nvim', { 'do': ':UpdateRemotePlugins'}

call plug#end()

"autocmd VimEnter * NERDTree

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
set ts=4 " Tab 너비
set shiftwidth=4 " 자동 인덴트할 때 너비
set hlsearch " 검색어 하이라이팅
set autowrite " 다른 파일로 넘어갈 때 자동 저장
"set sw=1 " 스크롤바 너비
set sts=4 "st select
set expandtab
set autoindent
colorscheme jellybeans
set showmatch " 일치하는 괄호 하이라이팅
set smartcase " 검색시 대소문자 구별
set smarttab
"set smartindent
"set softtabstop=4
"set tabstop=4
set list
set t_Co=256
map <silent> <C-s> :NERDTreeToggle<CR>
set cino=:0g0
command! MakeTags !ctags -R .
set path+=**
set clipboard=unnamedplus
let g:indent_guides_enable_on_vim_startup = 1
"let g:indent_guides_auto_colors = 0
autocmd VimEnter,Colorscheme * :hi IndentGuidesOdd  ctermbg=darkgrey
autocmd VimEnter,Colorscheme * :hi IndentGuidesEven ctermbg=darkgrey
let g:indent_guides_guide_size = 1
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#left_sep = ' '
let g:airline#extensions#tabline#left_alt_sep = '|'
let g:airline#extensions#tabline#formatter = 'unique_tail_improved'
let g:airline_theme='jellybeans'
let g:diminactive_use_syntax = 1
let g:diminactive_enable_focus = 1
let g:airline_powerline_fonts = 1
nmap <silent> ,n :bprevious<CR>
nmap <silent> ,m :bnext<CR>
nmap ,b= :!g++ <C-r>% -o <C-r>%.out<CR>
nmap ,r= :terminal ./<C-r>%.out<CR>
nmap ,rp :terminal python3 <C-r>%<CR>
nmap ,` :terminal<CR>
nmap ,bc :!gcc <C-r>% -o <C-r>%.out<CR>
nmap ,d= :!g++ -g <C-r>% -o <C-r>%.debug.out<CR>
nmap ,dc :!gcc -g <C-r>% -o <C-r>%.debug.out<CR>
nmap ,t :Tagbar<CR>
let g:indent_guides_indent_size = 4

