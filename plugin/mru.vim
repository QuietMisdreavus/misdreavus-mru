" misdreavus-mru: a most-recently-used buffer list for vim
" (c) QuietMisdreavus 2020

" This Source Code Form is subject to the terms of the Mozilla Public
" License, v. 2.0. If a copy of the MPL was not distributed with this
" file, You can obtain one at http://mozilla.org/MPL/2.0/.

function! s:include_buf_in_list(w, b)
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

    " if any buffer in the given window's MRU list is a help file, keep any other help file
    exe 'let list_has_help = ' . copy(g:misdreavus_mru[a:w])
        \ ->map({_, val -> getbufvar(val, '&buftype') == 'help'})
        \ ->join(' || ')
    if list_has_help && getbufvar(a:b, '&buftype') == 'help'
        return v:true
    endif

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
    if !exists('g:misdreavus_mru')
        return
    endif

    if !has_key(g:misdreavus_mru, a:w)
        let g:misdreavus_mru[a:w] = []
    endif
    let mru_list = g:misdreavus_mru[a:w]

    call filter(mru_list, {idx, val -> val != a:b})
    call insert(mru_list, a:b)
endfunction

function! s:leave_buf(w)
    if exists('g:misdreavus_mru') && has_key(g:misdreavus_mru, a:w)
        call filter(g:misdreavus_mru[a:w], {idx, val -> s:include_buf_in_list(a:w, val)})
    endif
endfunction

function! s:delete_buf(b)
    if exists('g:misdreavus_mru')
        for buflist in values(g:misdreavus_mru)
            call filter(buflist, {_, val -> val != a:b})
        endfor

        call filter(g:misdreavus_mru, '!empty(v:val)')
    endif
endfunction

function! s:clean_mru()
    if exists('g:misdreavus_mru')
        " don't keep MRU lists for windows that don't exists any more
        call filter(g:misdreavus_mru, 'win_id2win(v:key) != 0')
    endif
endfunction

function! s:print_mru(w, print_count)
    if !exists('g:misdreavus_mru')
        return
    endif

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
    if !exists('g:misdreavus_mru')
        return
    endif

    let w = win_getid()

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

function! s:save_mru_session()
    if !exists('g:misdreavus_mru')
        unlet! g:MisdreavusSessionMru
        return
    endif

    let g:MisdreavusSessionMru = SaveMruSession(g:misdreavus_mru)
endfunction

function! s:load_mru_session()
    if !exists('g:MisdreavusSessionMru')
        return
    endif

    let g:misdreavus_mru = LoadMruSession(g:MisdreavusSessionMru)
    unlet g:MisdreavusSessionMru

    " set the alternate file on windows with MRU lists
    let curwin = win_getid()
    tabdo windo call s:restore_alt_file()
    call win_gotoid(curwin)
endfunction

function! s:restore_alt_file()
    let wid = win_getid()
    if has_key(g:misdreavus_mru, wid) && len(g:misdreavus_mru[wid]) > 1
        " if the MRU list for this window has a second entry, set the alternate file to that
        let @# = g:misdreavus_mru[wid][1]
    else
        " otherwise, clear out the erroneous alternate file that came out of the session file
        " see https://github.com/vim/vim/issues/6714
        let @# = @%
    endif
endfunction

function! SaveMruSession(mru)
    " session_mru is a dict mapping buffer names to lists of other buffer names.
    " the idea is that if a buffer is visible under several windows, they'll have distinct MRU
    " lists, so it's worth it to save them separately. by taking each 'visible buffer' and mapping
    " over its window IDs, we can pop off the MRU lists in order and repopulate them after loading
    " the session back up.
    let session_mru = {}

    for [winid, bufs] in items(a:mru)
        let bname = winbufnr(winid)->bufname()
        if empty(bname)
            continue
        endif

        if !has_key(session_mru, bname)
            let session_mru[bname] = []
        endif

        let winbufs = map(copy(bufs), 'bufname(v:val)')
        call add(session_mru[bname], winbufs)
    endfor

    return string(session_mru)
endfunction

function! LoadMruSession(session_mru_str)
    let session_mru = eval(a:session_mru_str)

    let mru = {}

    for [curbuf, bufs] in items(session_mru)
        let curbufnum = bufnr(curbuf)
        if curbufnum == -1
            " hidden buffers didn't get saved, and this window didn't get saved, skip it
            continue
        endif

        let winids = win_findbuf(curbufnum)
        if empty(winids)
            " this window didn't get saved, skip it
            continue
        endif

        for wid in winids
            if empty(bufs)
                " there are somehow more windows with this buffer in the session than in the MRU
                " list? leave the later windows alone
                break
            endif

            let my_bufs = remove(bufs, 0)
            call map(my_bufs, 'bufnr(v:val)')
            call filter(my_bufs, 'v:val != -1')

            let mru[wid] = my_bufs
        endfor
    endfor

    return mru
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

        autocmd BufEnter * call <sid>push_buf(win_getid(), bufnr())
        autocmd BufLeave * call <sid>leave_buf(win_getid())
        autocmd BufDelete * call <sid>delete_buf(expand("<abuf>"))
        autocmd WinEnter * call <sid>clean_mru()

        autocmd User SessionSavePre call <sid>save_mru_session()
        autocmd SessionLoadPost * call <sid>load_mru_session()
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

command! -count Mru call <sid>print_mru(win_getid(), <count>)
command! EnableMru call <sid>enable_mru()
command! DisableMru call <sid>disable_mru()

nnoremap <Plug>RotateMru :call RotateMru()<CR>
