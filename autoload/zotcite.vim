
function zotcite#warning(wmsg)
    echohl WarningMsg
    echomsg a:wmsg
    echohl None
endfunction

function zotcite#info()
    if exists('g:zotcite_failed')
        call zotcite#warning(g:zotcite_failed)
        return
    endif
    let info = py3eval('ZotCite.Info()')
    for key in keys(info)
        echohl Title
        echo key
        echohl None
        echo info[key]
        echo ""
    endfor
endfunction

function zotcite#CompleteBib(findstart, base)
    if a:findstart
        let line = getline(".")
        let cpos = getpos(".")
        let idx = cpos[2] -2
        while line[idx] =~ '\w' && idx > 0
            let idx -= 1
        endwhile
        return idx + 1
    else
        let citeptrn = substitute(a:base, '^@', '', '')
        let resp = []
        let s:bib_finished = 0
        let lines = py3eval('ZotCite.GetMatch("'. citeptrn .'", "'. expand("%:p") .'")')
        for line in lines
            let tmp = split(line, "\x09")
            call add(resp, {'word': tmp[0], 'abbr': tmp[1], 'menu': tmp[2]})
        endfor
        return resp
    endif
endfunction

function zotcite#GetCitationKey()
    let oldisk = &iskeyword
    set iskeyword=@,48-57,_,192-255,@-@,#
    let wrd = expand('<cword>')
    exe 'set iskeyword=' . oldisk
    if wrd =~ '^@'
        let wrd = substitute(wrd, '^@', '', '')
        let wrd = substitute(wrd, '#.*', '', '')
        return wrd
    endif
    return ''
endfunction

function zotcite#GetReferenceData()
    let wrd = zotcite#GetCitationKey()
    if wrd != ''
        let repl = py3eval('ZotCite.GetRefData("' . wrd . '")')
        if has_key(repl, 'alastnm')
            echohl Identifier
            echon repl['alastnm'] . ' '
        endif
        echohl Number
        echon repl['year'] . ' '
        if has_key(repl, 'title')
            echohl Title
            echon repl['title']
            echohl None
        endif
    endif
endfunction

function zotcite#GetZoteroAttachment()
    let wrd = zotcite#GetCitationKey()
    if wrd != ''
        let repl = py3eval('ZotCite.GetAttachment("' . wrd . '")')
        if repl == 'nOaTtAChMeNt'
            call zotcite#warning(wrd . "'s attachment not found")
        elseif repl =~ 'nOcLlCtN:'
            call zotcite#warning('Collection "' . substitute(repl, 'nOcLlCtN:', '', '') . '" not found')
        elseif repl == 'nOcItEkEy'
            call zotcite#warning(wrd . " not found")
        elseif repl == ''
            call zotcite#warning('No reply from BibComplete')
        else
            let fpath = repl
            let fpath = expand('~/Zotero/storage/') . substitute(repl, ':storage:', '/', '')
            if filereadable(fpath)
                call system(s:open_cmd . ' "' . fpath . '"')
            else
                call zotcite#warning('Could not find "' . fpath . '"')
            endif
        endif
    endif
endfunction

function zotcite#GetYamlField(field)
    if getline(1) != '---'
        return []
    endif
    let value = []
    let lastl = line('$')
    let idx = 2
    while idx < lastl
        let line = getline(idx)
        if line == '...' || line == '---'
            break
        endif
        if line =~ '^\s*' . a:field . '\s*:'
            let bstr = substitute(line, '^\s*' . a:field . '\s*:\s*\(.*\)\s*', '\1', '')
            if bstr =~ '^".*"$' || bstr =~ "^'.*'$"
                let bib = substitute(bstr, '"', '', 'g')
                let bib = substitute(bib, "'", '', 'g')
                let bibl = [bib]
            elseif bstr =~ '^\[.*\]$'
                try
                    let l:bbl = eval(bstr)
                catch *
                    call zotcite#warning('YAML line invalid for the zotcite plugin: ' . line)
                    let bibl = []
                endtry
                if exists('l:bbl')
                    let bibl = l:bbl
                endif
            else
                let bibl = [bstr]
            endif
            for fn in bibl
                call add(value, fn)
            endfor
            break
        endif
        let idx += 1
    endwhile
    return value
endfunction

function zotcite#GetCollectionName()
    let newc = zotcite#GetYamlField('collection')
    if !exists('b:zotcite_cllctn') || newc != b:zotcite_cllctn
        let b:zotcite_cllctn = newc
        let repl = py3eval('ZotCite.SetCollections("' . expand("%:p") . '", ' . string(b:zotcite_cllctn) . ')')
        if repl != ''
            call zotcite#warning(repl)
        endif
    endif
endfunction

function zotcite#GlobalInit()
    command Zinfo call zotcite#info()
    if !has('python3')
        let g:zotcite_failed = 'zotcite requires python3'
        call zotcite#warning(g:zotcite_failed)
        return 0
    endif

    if has('win32') || system("uname") =~ "Darwin"
        let s:open_cmd = 'open'
    else
        let s:open_cmd = 'xdg-open'
    endif

    py3 import os

    " Start ZoteroEntries
    py3 from zotero import ZoteroEntries
    py3 ZotCite = ZoteroEntries()

    " Get information from ZoteroEntries and set environment variables for citeref
    let info = py3eval('ZotCite.Info()')
    let $Zotcite_tmpdir = info['tmpdir']
    let zotcite_home = substitute(info['zotero.py'], '\(.*\)/.*', '\1', '')
    if $PATH !~ zotcite_home
        if has("win32")
            let $PATH = zotcite_home . ';' . $PATH
        else
            let $PATH = zotcite_home . ':' . $PATH
        endif
    endif
    let $RmdFile = expand("%:p")

    call zotcite#GetCollectionName()
    return 1
endfunction

function zotcite#Init()
    let ok = 0
    for ft in g:zotcite_filetypes
        if &filetype == ft
            let ok = 1
            break
        endif
    endfor

    if ok == 0
        return
    endif

    " Do this only once
    if !exists('s:open_cmd')
        if zotcite#GlobalInit() == 0
            return
        endif
    endif

    " And repeat this for every buffer
    if !exists('b:zotref_did_buffer_cmds')
        let b:zotref_did_buffer_cmds = 1
        if hasmapto('<Plug>ZOpenAttachment', 'n')
            exec 'nnoremap <buffer><silent> <Plug>ZOpenAttachment :call zotcite#GetZoteroAttachment()<cr>'
        else
            nnoremap <buffer><silent> <Leader>zo :call zotcite#GetZoteroAttachment()<cr>
        endif
        if hasmapto('<Plug>ZCitationInfo', 'n')
            exec 'nnoremap <buffer><silent> <Plug>ZCitationInfo :call zotcite#GetReferenceData()<cr>'
        else
            nnoremap <buffer><silent> <Leader>zi :call zotcite#GetReferenceData()<cr>
        endif
        if exists('g:zotcite_conceallevel')
            exe 'set conceallevel=' . g:zotcite_conceallevel
        else
            set conceallevel=2
        endif
        setlocal omnifunc=zotcite#CompleteBib
    endif
endfunction

