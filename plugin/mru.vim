" misdreavus-mru: a most-recently-used buffer list for vim
" (c) QuietMisdreavus 2020

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

function! s:push_buf(b)
    call filter(g:misdreavus_mru, {idx, val -> val != a:b})
    call insert(g:misdreavus_mru, a:b)
endfunction

function! s:leave_buf()
    call filter(g:misdreavus_mru, {idx, val -> s:include_buf_in_list(val)})
endfunction

function! s:print_mru(print_count)
    let print_count = a:print_count
    if print_count == 0
        let print_count = len(g:misdreavus_mru)
    endif
    let printed = 0

    for b in g:misdreavus_mru
        if b == bufnr()
            let flag = '%'
        elseif b == bufnr('#')
            let flag = '#'
        else
            let flag = ' '
        endif
        let buf_display = flag . b . ':'

        echo buf_display bufname(b)

        let printed += 1
        if printed == print_count
            break
        endif
    endfor
endfunction

function! s:enable_mru()
    if !exists('g:misdreavus_mru')
        let g:misdreavus_mru = []
    endif

    augroup MisdreavusMru
        autocmd!

        autocmd BufEnter * call <sid>push_buf(bufnr())
        autocmd BufLeave * call <sid>leave_buf()
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

command! -count Mru call <sid>print_mru(<count>)
command! EnableMru call <sid>enable_mru()
command! DisableMru call <sid>disable_mru()
