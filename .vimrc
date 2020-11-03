syntax on
set cindent
set number
set ts=4 " Tab 너비
set shiftwidth=4 " 자동 인덴트할 때 너비
set hlsearch " 검색어 하이라이팅
set autowrite " 다른 파일로 넘어갈 때 자동 저장
set sts=4 "st select
set expandtab
set autoindent
set showmatch " 일치하는 괄호 하이라이팅
set smartcase " 검색시 대소문자 구별
set smarttab
set list
set t_Co=256
set cino=:0g0
set path+=**
nmap <silent> ,n :bprevious<CR>
nmap <silent> ,m :bnext<CR>
nmap ,b= :!g++ <C-r>% -o <C-r>%.out<CR>
nmap ,r= :terminal ./<C-r>%.out<CR>
nmap ,rp :terminal python3 <C-r>%<CR>
nmap ,` :terminal<CR>
nmap ,bc :!gcc <C-r>% -o <C-r>%.out<CR>
nmap ,d= :!g++ -g <C-r>% -o <C-r>%.debug.out<CR>
nmap ,dc :!gcc -g <C-r>% -o <C-r>%.debug.out<CR>
nmap ,w :%s/\r//g<CR>
nmap ,s :%s/<C-i>/    /g<CR>
