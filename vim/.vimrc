source ~/.vim/bundles.vim

" encoding dectection
set fileencodings=utf-8,gb2312,gb18030,gbk,ucs-bom,cp936,latin1

" enable filetype dectection and ft specific plugin/indent
filetype plugin indent on

" enable syntax hightlight and completion
syntax on

"--------
" Vim UI
"--------
" color scheme
" set background=dark
" color solarized
colorscheme desert

" highlight current line
" au WinLeave * set nocursorline nocursorcolumn
" au WinEnter * set cursorline cursorcolumn
" set cursorline cursorcolumn

" search
set incsearch
"set highlight 	" conflict with highlight current line
set smartcase
set hlsearch
set cc=80 " 设置标尺,高亮显示第80行
set ignorecase

" editor settings
set history=1000
set nocompatible
set nofoldenable                                                  " disable folding"
set confirm                                                       " prompt when existing from an unsaved file
set backspace=indent,eol,start                                    " More powerful backspacing
set t_Co=256                                                      " Explicitly tell vim that the terminal has 256 colors "
set mouse=a                                                       " use mouse in all modes
set report=0                                                      " always report number of lines changed                "
set nowrap                                                        " dont wrap lines
set scrolloff=5                                                   " 5 lines above/below cursor when scrolling
set number                                                        " show line numbers
set showmatch                                                     " show matching bracket (briefly jump)
set showcmd                                                       " show typed command in status bar
set title                                                         " show file in titlebar
set laststatus=2                                                  " use 2 lines for the status bar
set matchtime=2                                                   " show matching bracket for 0.2 seconds
set matchpairs+=<:>                                               " specially for html
" set relativenumber

" Default Indentation
" set autoindent
" set smartindent     " indent when
set tabstop=4       " tab width
set softtabstop=4   " backspace
set shiftwidth=4    " indent width
" set textwidth=79
" set smarttab
set expandtab       " expand tab to space

autocmd FileType php setlocal tabstop=2 shiftwidth=2 softtabstop=2 textwidth=120
autocmd FileType ruby setlocal tabstop=2 shiftwidth=2 softtabstop=2 textwidth=120
autocmd FileType php setlocal tabstop=4 shiftwidth=4 softtabstop=4 textwidth=120
autocmd FileType coffee,javascript setlocal tabstop=2 shiftwidth=2 softtabstop=2 textwidth=120
autocmd FileType python setlocal tabstop=4 shiftwidth=4 softtabstop=4 textwidth=120
autocmd FileType html,htmldjango,xhtml,haml setlocal tabstop=2 shiftwidth=2 softtabstop=2 textwidth=0
autocmd FileType sass,scss,css setlocal tabstop=2 shiftwidth=2 softtabstop=2 textwidth=120

" syntax support
autocmd Syntax javascript set syntax=jquery   " JQuery syntax support
" js
let g:html_indent_inctags = "html,body,head,tbody"
let g:html_indent_script1 = "inc"
let g:html_indent_style1 = "inc"

let g:auto_save = 1  " enable AutoSave on Vim startup"

" leader key
let mapleader = "\<Space>"

nmap <leader><leader>w :wa<cr>
nmap <leader><leader>q :wqa<cr>
nmap <leader>m :set modifiable<cr>

"-----------------
" Plugin settings
"-----------------
" Rainbow parentheses for Lisp and variants
let g:rbpt_colorpairs = [
    \ ['brown',       'RoyalBlue3'],
    \ ['Darkblue',    'SeaGreen3'],
    \ ['darkgray',    'DarkOrchid3'],
    \ ['darkgreen',   'firebrick3'],
    \ ['darkcyan',    'RoyalBlue3'],
    \ ['darkred',     'SeaGreen3'],
    \ ['darkmagenta', 'DarkOrchid3'],
    \ ['brown',       'firebrick3'],
    \ ['gray',        'RoyalBlue3'],
    \ ['black',       'SeaGreen3'],
    \ ['darkmagenta', 'DarkOrchid3'],
    \ ['Darkblue',    'firebrick3'],
    \ ['darkgreen',   'RoyalBlue3'],
    \ ['darkcyan',    'SeaGreen3'],
    \ ['darkred',     'DarkOrchid3'],
    \ ['red',         'firebrick3'],
    \ ]
let g:rbpt_max = 16
autocmd Syntax lisp,scheme,clojure,racket RainbowParenthesesToggle

" tabbar
let g:Tb_MaxSize = 2
let g:Tb_TabWrap = 1

hi Tb_Normal guifg=white ctermfg=white
hi Tb_Changed guifg=green ctermfg=green
hi Tb_VisibleNormal ctermbg=252 ctermfg=235
hi Tb_VisibleChanged guifg=green ctermbg=252 ctermfg=white

" easy-motion
let g:EasyMotion_leader_key = '<Leader>'

" Tagbar
let g:tagbar_left=1
let g:tagbar_width=30
let g:tagbar_autofocus = 1
let g:tagbar_sort = 0
let g:tagbar_compact = 1
" tag for coffee
if executable('coffeetags')
  let g:tagbar_type_coffee = {
        \ 'ctagsbin' : 'coffeetags',
        \ 'ctagsargs' : '',
        \ 'kinds' : [
        \ 'f:functions',
        \ 'o:object',
        \ ],
        \ 'sro' : ".",
        \ 'kind2scope' : {
        \ 'f' : 'object',
        \ 'o' : 'object',
        \ }
        \ }

  let g:tagbar_type_markdown = {
    \ 'ctagstype' : 'markdown',
    \ 'sort' : 0,
    \ 'kinds' : [
        \ 'h:sections'
    \ ]
    \ }
endif

" Nerd Tree
let NERDChristmasTree=0
let NERDTreeWinSize=30
let NERDTreeChDirMode=2
let NERDTreeIgnore=['\~$', '\.pyc$', '\.swp$']
" let NERDTreeSortOrder=['^__\.py$', '\/$', '*', '\.swp$',  '\~$']
let NERDTreeShowBookmarks=1
let NERDTreeWinPos = "right"

" nerdcommenter
let NERDSpaceDelims=1
" nmap <D-/> :NERDComToggleComment<cr>
let NERDCompactSexyComs=1

" ZenCoding
let g:user_emmet_expandabbr_key='<C-j>'

" powerline
"let g:Powerline_symbols = 'fancy'

" NeoComplCache
let g:neocomplcache_enable_at_startup=1
let g:neoComplcache_disableautocomplete=1
"let g:neocomplcache_enable_underbar_completion = 1
"let g:neocomplcache_enable_camel_case_completion = 1
let g:neocomplcache_enable_smart_case=1
let g:neocomplcache_min_syntax_length = 3
let g:neocomplcache_lock_buffer_name_pattern = '\*ku\*'
set completeopt-=preview

imap <C-k> <Plug>(neocomplcache_snippets_force_expand)
smap <C-k> <Plug>(neocomplcache_snippets_force_expand)
imap <C-l> <Plug>(neocomplcache_snippets_force_jump)
smap <C-l> <Plug>(neocomplcache_snippets_force_jump)

" Enable omni completion.
autocmd FileType css setlocal omnifunc=csscomplete#CompleteCSS
autocmd FileType html,markdown setlocal omnifunc=htmlcomplete#CompleteTags
autocmd FileType javascript setlocal omnifunc=javascriptcomplete#CompleteJS
autocmd FileType python setlocal omnifunc=pythoncomplete#Complete
autocmd FileType c setlocal omnifunc=ccomplete#Complete
if !exists('g:neocomplcache_omni_patterns')
  let g:neocomplcache_omni_patterns = {}
endif
let g:neocomplcache_omni_patterns.erlang = '[a-zA-Z]\|:'

" SuperTab
" let g:SuperTabDefultCompletionType='context'
let g:SuperTabDefaultCompletionType = '<C-X><C-U>'
let g:SuperTabRetainCompletionType=2

" quickfix
nnoremap <Leader>O :copen 7<CR>
nnoremap <Leader>C :cclose<CR>
nnoremap <Leader>F :col<CR>
nnoremap <Leader>W :cw<CR>
nnoremap <Leader>L :cl<CR>
nnoremap <Leader>cp :cp<CR>
nnoremap <Leader>N :cn<CR>
nnoremap <Leader>X :cnew<CR>




" ctrlp
set wildignore+=*/tmp/*,*.so,*.o,*.a,*.obj,*.swp,*.zip,*.pyc,*.pyo,*.class,.DS_Store  " MacOSX/Linux
let g:ctrlp_use_caching = 0
"修改QuickFix窗口显示的最大条目数
let g:ctrlp_max_height = 5
let g:ctrlp_match_window_reversed = 0
"默认使用全路径搜索，置1后按文件名搜索，准确率会有所提高，可以用<C-d>进行切换
let g:ctrlp_by_filename = 1
"调用ag进行搜索提升速度，同时不使用缓存文件
if executable('ag')
  set grepprg=ag\ --nogroup\ --nocolor
    let g:ctrlp_user_command = 'ag %s -l --nocolor -g "'
      let g:ctrlp_use_caching = 0
endif

"设置搜索时忽略的文件
let g:ctrlp_custom_ignore = {
    \ 'dir':  '\v[\/]\.(git|hg|svn|rvm)$',
        \ 'file': '\v\.(exe|so|dll|zip|tar|tar.gz|pyc|vim|out)$',
            \ }

" hu add
if executable('ag')
"    set grepprg=ag --nogroup --nocolor
    let g:ctrlp_user_command = 'ag %s -l --nocolor -g ""'
else
    let g:ctrlp_user_command = ['.git', 'cd %s && git ls-files . -co --exclude-standard', 'find %s -type f']
    let g:ctrlp_prompt_mappings = {
    'AcceptSelection("e")': ['<space>', '<cr>', '<2-LeftMouse>'],
    }
endif


" vimgrep /匹配模式/[g][j] 要搜索的文件/范围
" g：表示是否把每一行的多个匹配结果都加入
" j：表示是否搜索完后定位到第一个匹配位置
" vimgrep /pattern/ %           在当前打开文件中查找
" vimgrep /pattern/ *             在当前目录下查找所有
" vimgrep /pattern/ **            在当前目录及子目录下查找所有
" vimgrep /pattern/ *.c          查找当前目录下所有.c文件
" vimgrep /pattern/ **/*         只查找子目录]]

"               在当前文件中快速查找光标下的单词
nmap <leader>lv :lv /<c-r>=expand("<cword>")<cr>/ %<cr>:lw<cr>

"-----Command-T-----
let g:CommandTFileScanner = 'ruby'   "使用ruby作为文件浏览
let g:CommandTTraverseSCM = 'dir'    "根目录为执行vim时所在的目录
"打开文件跳转
nnoremap <silent> <Leader>f :CommandT<CR>

"-----cscope-----
" 加载cscope库
" https://my.oschina.net/u/572632/blog/267471
if has("cscope")
if filereadable("cscope.out")
    set nocscopeverbose
    cs add cscope.out
elseif $CSCOPE_DB  != ""
    cs add $CSCOPE_DB
else
    let cscope_file=findfile("cscope.out", ".;")
    let cscope_pre=matchstr(cscope_file, ".*/")
    "if !empty(cscope_file) &&
        "filereadable(cscope_file)
        "exe "cs add" cscope_file cscope_pre
    "endif
endif
endif


" set cscopequickfix=s-,c-,d-,i-,t-,e- "使用quickfix窗口显示结果
set cscopequickfix=s0,c0,d0,i0,t0,e0 " ’0’或者不设置表示不使用quickfix窗口
set cst                              "跳转时也使用cscope库
set csto=0
set cspc=0
"打开引用窗口
nnoremap <silent><Leader>cw :cw<CR>
""重新生成索引文件
"" find `pwd` -name *.py > cscope.files  ==> cscope -Rbqk -i cscope.files 
nnoremap <silent><Leader>bc :!cscope -Rbq<CR>
"s: 查找本C符号
nnoremap <C-@>s :scs find s <C-R>=expand("<cword>")<CR><CR>
"g: 查找本定义
nnoremap <C-@>g :scs find g <C-R>=expand("<cword>")<CR><CR>
"t: 查找本字符串
nnoremap <C-@>t :scs find t <C-R>=expand("<cword>")<CR><CR>
"e: 查找本egrep模式
nnoremap <C-@>e :scs find e <C-R>=expand("<cword>")<CR><CR>
"f: 查找本文件
nnoremap <C-@>f :scs find f <C-R>=expand("<cfile>")<CR><CR>
"i: 查找包含本文件的文件
nnoremap <C-@>i :scs find i <C-R>=expand("<cfile>")<CR><CR>
"d: 查找本函数调用的函数
nnoremap <C-@>d :scs find d <C-R>=expand("<cword>")<CR><CR>
"c: 查找调用本函数的函数
nnoremap <C-@>c :scs find c <C-R>=expand("<cword>")<CR><CR>

nnoremap <leader>fa :call CscopeFindInteractive(expand('<cword>'))<CR>
nnoremap <leader>l :call ToggleLocationList()<CR>

"s: Find this C symbol
nnoremap  <leader>fs :call CscopeFind('s', expand('<cword>'))<CR>
" g: Find this definition
nnoremap  <leader>fg :call CscopeFind('g', expand('<cword>'))<CR>
" d: Find functions called by this function
nnoremap  <leader>fd :call CscopeFind('d', expand('<cword>'))<CR>
" c: Find functions calling this function
nnoremap  <leader>fc :call CscopeFind('c', expand('<cword>'))<CR>
" t: Find this text string
nnoremap  <leader>ft :call CscopeFind('t', expand('<cword>'))<CR>
" e: Find this egrep pattern
nnoremap  <leader>fe :call CscopeFind('e', expand('<cword>'))<CR>
" f: Find this file
nnoremap  <leader>ff :call CscopeFind('f', expand('<cword>'))<CR>
" i: Find files #including this file
nnoremap  <leader>fi :call CscopeFind('i', expand('<cword>'))<CR>


" Keybindings for plugin toggle
nnoremap <F2> :set invpaste paste?<CR>
set pastetoggle=<F2>
nmap <F5> :TagbarToggle<cr>
nmap <F6> :NERDTreeToggle<cr>
nmap <F3> :GundoToggle<cr>
nmap <F4> :IndentGuidesToggle<cr>
nmap  <D-/> :

" Ack usage:
"
" ?           帮助，显示所有快捷键
" Enter/o     打开文件
" O           打开文件并关闭Quickfix
" go          预览文件，焦点仍然在Quickfix
" t           新标签页打开文件
" q           关闭Quickfix
"
map <buffer> <leader><space> :w<cr>:make<cr>
nnoremap <Leader>N :cn<cr>
nnoremap <Leader>cp :cp<cr>
nnoremap <Leader>W :cw 10<cr>
nnoremap <Leader>O :copen 10<cr>
nnoremap <Leader>C :cclose<cr>

nnoremap <Leader>a :Ack<space>
" 忽略大小写
nnoremap <Leader>A :Ack -i<space>
nnoremap <Leader>v V`]

"------------------
" Useful Functions
"------------------
" easier navigation between split windows
nnoremap <c-j> <c-w>j
nnoremap <c-k> <c-w>k
nnoremap <c-h> <c-w>h
nnoremap <c-l> <c-w>l

" When editing a file, always jump to the last cursor position
autocmd BufReadPost *
      \ if ! exists("g:leave_my_cursor_position_alone") |
      \     if line("'\"") > 0 && line ("'\"") <= line("$") |
      \         exe "normal g'\"" |
      \     endif |
      \ endif

" w!! to sudo & write a file
cmap w!! %!sudo tee >/dev/null %

" Quickly edit/reload the vimrc file
nmap <silent> <Leader>ev :e $MYVIMRC<CR>
nmap <silent> <Leader>sv :so $MYVIMRC<CR>

" sublime key bindings
nmap <D-]> >>
nmap <D-[> <<
vmap <D-[> <gv
vmap <D-]> >gv

" eggcache vim
nnoremap ; :
:command W w
:command WQ wq
:command Wq wq
:command Q q
:command Qa qa
:command QA qa

" for macvim
if has("gui_running")
    set go=aAce  " remove toolbar
    "set transparency=30
    set guifont=Monaco:h13
    set showtabline=2
    set columns=140
    set lines=40
    noremap <D-M-Left> :tabprevious<cr>
    noremap <D-M-Right> :tabnext<cr>
    map <D-1> 1gt
    map <D-2> 2gt
    map <D-3> 3gt
    map <D-4> 4gt
    map <D-5> 5gt
    map <D-6> 6gt
    map <D-7> 7gt
    map <D-8> 8gt
    map <D-9> 9gt
    map <D-0> :tablast<CR>
endif


" =========================== hu add ============================
"
" 重新生成标签
nnoremap <silent><Leader>bt :!~/.vim/hitags.sh<CR>

" 高亮标签
nnoremap <silent><Leader>ht :so tags.vim<CR>

" vim-expand-region
vmap v <Plug>(expand_region_expand)
vmap <C-v> <Plug>(expand_region_shrink)

" ack.vim
let g:ackprg = 'ag --nogroup --nocolor --column'

" 使用 <Space>o 创建一个新文件
nnoremap <Leader>o :CtrlP<CR>
" 使用 <Space>w 保存文件
nnoremap <Leader>w :w<CR>
" 使用 <Space>p 与 <Space>y 进行剪切板拷贝、粘贴
vmap <Leader>y "+y
vmap <Leader>d "+d
nmap <Leader>p "+p
nmap <Leader>P "+P
vmap <Leader>p "+p
vmap <Leader>P "+P

" 使用 ppppp 进行多行多次粘贴操作
vnoremap <silent> y y`]
vnoremap <silent> p p`]
nnoremap <silent> p p`]

"删除行末空格
nmap <leader>tt :%s/\s\+$//<CR>

" 通过以下的配置可以避免缓冲区的内容被删除的文本内容所覆盖（放到~/.vimrc文件的最后）
function! RestoreRegister()
    let @" = s:restore_reg
    return ''
endfunction
function! s:Repl()
    let s:restore_reg = @"
    return "p@=RestoreRegister()<cr>"
endfunction
vmap <silent> <expr> p <sid>Repl()


"文件搜索路径
"set path=.,/usr/include,,
"
"  " 控制
"  set nocompatible              "关闭vi兼容
"  filetype off                  "关闭文件类型侦测,vundle需要
"  set fileencodings=utf-8,gbk   "使用utf-8或gbk编码方式
"  syntax on                     "语法高亮
"  set backspace=2               "退格键正常模式
"  set whichwrap=<,>,[,]         "当光标到行首或行尾，允许左右方向键换行
"  set autoread                  "文件在vim外修改过，自动重载
"  set nobackup                  "不使用备份
"  set confirm                   "在处理未保存或只读文件时，弹出确认消息
"  set scrolloff=3               "光标移动到距离顶部或底部开始滚到距离
"  set history=1000              "历史记录数
"  set mouse=                    "关闭鼠标
"  set selection=inclusive       "选择包含最后一个字符
"  set selectmode=mouse,key      "启动选择模式的方式
"  set completeopt=longest,menu  "智能补全,弹出菜单，无歧义时才自动填充
"  set noswapfile                "关闭交换文件
"  set hidden                    "允许在有未保存的修改时切换缓冲区
"
"    "显示
"    colorscheme mycolor           "选择配色方案
"    set t_Co=256                  "可以使用的颜色数目
"    set number                    "显示行号
"    set laststatus=2              "显示状态行
"    set ruler                     "显示标尺
"    set showcmd                   "显示输入的命令
"    set showmatch                 "高亮括号匹配
"    set matchtime=1               "匹配括号高亮的时间(十分之一秒)
"    set matchpairs={:},(:)        "匹配括号"{}"()"
"    set hlsearch                  "检索时高亮匹配项
"    set incsearch                 "边检索边显示匹配
"    set go-=T                     "去除gvim的toolbar
"
"      "格式
"      set noexpandtab               "不要将tab转换为空格
"      set shiftwidth=4              "自动缩进的距离,也是平移字符的距离
"      set tabstop=4                 "tab键对应的空格数
"      set autoindent                "自动缩进
"      set smartindent               "智能缩进
"
"
"          "===================按键映射======================
"
"
"              "使用Ctrl-l 和 Ctrl+h 切换标签页
"              nnoremap <C-l> gt
"              nnoremap <c-h> gT
"
"                "在行末加上分号
"                nnoremap <silent> <Leader>; :<Esc><End>a<Space>;<Esc><Down>
"                "保存
"                nnoremap <C-s> :w<CR>
"                "替换
"                nnoremap <C-h>
"                :%s/<C-R>=expand("<cword>")<CR>/<C-R>=expand("<cword>")<CR>
"                ))>)"
"
"                %s/\s\+$//   删掉末尾空格
"
" % 跳转到相配对的括号
" gD 跳转到局部变量的定义处
" '' 跳转到光标上次停靠的地方, 是两个', 而不是一个"
" mx 设置书签,x只能是a-z的26个字母
" `x 跳转到书签处("`"是1左边的键)
" > 增加缩进,"x>"表示增加以下x行的缩进
" < 减少缩进,"x<"表示减少以下x行的缩进
" { 跳到上一段的开头
" 跳到下一段的的开头
" ( 移到这个句子的开头
" ) 移到下一个句子的开头
" [[ 跳转至上一个函数(要求代码块中'{'必须单独占一行)
" ]] 跳转至下一个函数(要求代码块中'{'必须单独占一行)

" C-] 跳转至函数或变量定义处
" C-O 返回跳转前位置
" C-T 同上
" nC-T 返回跳转 n 次

" 0 数字0,跳转至行首
" ^ 跳转至行第一个非空字符
" $ 跳转至行尾  })})">`")`
"
"
" <C-R> 0 复制copy
"
"
"
"
"
" 折叠命令 zc 关闭当前打开的折叠
" zo 打开当前的折叠
"
"
" zm 关闭所有折叠
" zM 关闭所有折叠及其嵌套的折叠
" zr 打开所有折叠
" zR 打开所有折叠及其嵌套的折叠
"
"
" zd 删除当前折叠
" zE 删除所有折叠
"
"
" zj 移动至下一个折叠
" zk 移动至上一个折叠
"
"
" zn 禁用折叠
" zN 启用折叠
