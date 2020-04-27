set nocompatible
filetype off
set rtp+=~/.vim/bundle/Vundle.vim 
call vundle#begin()
Plugin 'Vundlevim/Vundle.vim'
Plugin 'vim-airline/vim-airline'
Plugin 'scrooloose/nerdtree'
Plugin 'airblade/vim-gitgutter'
Plugin 'octol/vim-cpp-enhanced-highlight'
Plugin 'tpope/vim-fugitive'
Plugin 'scrooloose/syntastic'
Plugin 'nanotech/jellybeans.vim' 

call vundle#end()
filetype plugin indent on

autocmd VimEnter * NERDTree
autocmd VimEnter * wincmd p
syntax on
set autoindent
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
set sw=1 " 스크롤바 너비
set sts=4 "st select
colorscheme jellybeans
set showmatch " 일치하는 괄호 하이라이팅
set smartcase " 검색시 대소문자 구별
set smarttab
set smartindent
set softtabstop=4
set tabstop=4
set list
