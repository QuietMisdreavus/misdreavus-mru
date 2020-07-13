" misdreavus-mru: a most-recently-used buffer list for vim
" (c) QuietMisdreavus 2020

" This Source Code Form is subject to the terms of the Mozilla Public
" License, v. 2.0. If a copy of the MPL was not distributed with this
" file, You can obtain one at http://mozilla.org/MPL/2.0/.

function! s:include_buf_in_list(b)
    " never list buffers that have been deleted
    if !bufexists(a:b)
        return v:false
    endif

    " always list visible buffers, on any tab page
    for t in range(1, tabpagenr('$'))
        if index(tabpagebuflist(t), a:b) > -1
            return v:true
        endif
    endfor

    " if a buffer isn't listed in `:ls`, don't list it in `:Mru`
    if !buflisted(a:b)
        return v:false
    endif

    " don't list quickfix/location list buffers
    if getbufvar(a:b, '&filetype') == 'qf'
        return v:false
    endif

    " if a buffer didn't get filtered out from the other filters, list it
    return v:true
endfunction

function! s:push_buf(w, b)
    if !has_key(g:misdreavus_mru, a:w)
        let g:misdreavus_mru[a:w] = []
    endif
    let mru_list = g:misdreavus_mru[a:w]

    call filter(mru_list, {idx, val -> val != a:b})
    call insert(mru_list, a:b)
endfunction

function! s:leave_buf(w)
    if has_key(g:misdreavus_mru, a:w)
        call filter(g:misdreavus_mru[a:w], {idx, val -> s:include_buf_in_list(val)})
    endif
endfunction

function! s:print_mru(w, print_count)
    if !has_key(g:misdreavus_mru, a:w)
        echo 'No MRU list available for the current window'
        return
    endif

    let mru_list = g:misdreavus_mru[a:w]
    let print_count = a:print_count
    if print_count == 0
        let print_count = len(mru_list)
    endif
    let printed = 0

    for b in mru_list
        if b == bufnr()
            let flag = '%'
        elseif b == bufnr('#')
            let flag = '#'
        else
            let flag = ' '
        endif
        let buf_display = flag . b . ":\t"

        echo buf_display bufname(b)

        let printed += 1
        if printed == print_count
            break
        endif
    endfor
endfunction

function! RotateMru()
    let w = winnr()

    if !has_key(g:misdreavus_mru, w)
        return
    endif
    let mru_list = g:misdreavus_mru[w]

    let len = len(mru_list)
    let rot = g:misdreavus_mru_rotate_count

    if rot <= 0
        return
    endif

    if rot <= len
        let b = mru_list[rot - 1]
    elseif len > 0
        let b = mru_list[-1]
    else
        return
    endif

    execute "buffer" b
endfunction

function! s:enable_mru()
    if !exists('g:misdreavus_mru')
        let g:misdreavus_mru = {}
    endif

    if !exists('g:misdreavus_mru_rotate_count')
        let g:misdreavus_mru_rotate_count = 3
    endif

    augroup MisdreavusMru
        autocmd!

        autocmd BufEnter * call <sid>push_buf(winnr(), bufnr())
        autocmd BufLeave * call <sid>leave_buf(winnr())
    augroup END
endfunction

function! s:disable_mru()
    unlet! g:misdreavus_mru

    augroup MisdreavusMru
        autocmd!
    augroup END
endfunction

if !exists('g:misdreavus_mru_no_auto_enable')
    call s:enable_mru()
endif

command! -count Mru call <sid>print_mru(winnr(), <count>)
command! EnableMru call <sid>enable_mru()
command! DisableMru call <sid>disable_mru()

nnoremap <Plug>RotateMru :call RotateMru()<CR>
