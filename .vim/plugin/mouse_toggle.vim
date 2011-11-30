" plugin/mouse_toggle.vim
"	<plug>mouse_toggle -> toggle 'mouse' option
"	<leader>m -> <plug>mouse_toggle
"	Written by Kobus Retief

if !has("mouse")
    finish
endif

if exists("loaded_mouse_toggle")
    finish
endif
let loaded_mouse_toggle = 1

let s:save_cpo = &cpo
set cpo&vim

let s:oldmouse = exists("mouse_default") ? mouse_default : "a"

function s:mouse_toggle()
    if &mouse == ""
        let &mouse = s:oldmouse
        set number
        echo "mouse enabled (=" . &mouse . ")"
    else
        let s:oldmouse = &mouse
        let &mouse = ""
        set nonumber
        echo "mouse disabled"
    endif
endfunction

nnoremap <unique> <silent> <plug>mouse_toggle :call <sid>mouse_toggle()<cr>
if ! hasmapto("<plug>mouse_toggle")
    map <unique> <leader>m <plug>mouse_toggle
endif


let &cpo = s:save_cpo
unlet s:save_cpo

