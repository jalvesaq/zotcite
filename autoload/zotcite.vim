
function zotcite#warning(wmsg)
    if v:vim_did_enter == 0
        exe 'autocmd VimEnter * call zotcite#warning("' . escape(a:wmsg, '"') . '")'
        return
    endif
    echohl WarningMsg
    echomsg a:wmsg
    echohl None
endfunction

function zotcite#info()
    if exists('g:zotcite_failed')
        call zotcite#warning(g:zotcite_failed)
        return
    endif
    if s:zrunning
        let info = py3eval('ZotCite.Info()')
        echohl Statement
        echo 'Information from the Python module:'
        for key in keys(info)
            echohl Title
            echo '  ' . key . repeat(' ', 18 - len(key))
            echohl None
            echon ': ' .info[key]
        endfor
    endif
    if s:log != [] || (&omnifunc != '' && &omnifunc != 'zotcite#CompleteBib')
        if s:zrunning
            echo " "
            echohl Statement
            echo 'Additional messages:'
            echohl None
        endif
        if &omnifunc != 'zotcite#CompleteBib'
            echo 'There is another omnifunc enabled: ' . &omnifunc
        endif
        for line in s:log
            echo line
        endfor
    endif
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
        let lines = py3eval('ZotCite.GetMatch("'. citeptrn .'", "'. escape(expand("%:p"), '\\') .'")')
        for line in lines
            let tmp = split(line, "\x09")
            call add(resp, {'word': tmp[0], 'abbr': tmp[1], 'menu': tmp[2]})
        endfor
        return resp
    endif
endfunction

function zotcite#Seek(key)
    let citeptrn = substitute(a:key, ' .*', '', '')
    let lines = py3eval('ZotCite.GetMatch("'. citeptrn .'", "'. escape(expand("%:p"), '\\') .'")')
    let resp = ''
    for line in lines
        let tmp = split(line, "\x09")
        echohl Identifier
        echo tmp[1] . ' '
        if tmp[2] =~ '^([0-9][0-9][0-9][0-9]) '
            let year = substitute(tmp[2], '^(\([0-9][0-9][0-9][0-9]\)) .*', '\1', '')
            let ttl = substitute(tmp[2], '^([0-9][0-9][0-9][0-9]) ', '', '')
        elseif tmp[2] =~ '^() '
            let year = ''
            let ttl = substitute(tmp[2], '^() ', '', '')
        else
            let year = ''
            let ttl = tmp[2]
        endif
        let room = &columns - len(tmp[1]) - len(year) - 3
        if len(ttl) > room
            let ttl = substitute(ttl, '^\(.\{'.room.'}\).*', '\1', '')
        endif
        echohl Number
        echon  year . ' '
        echohl Title
        echon ttl
        echohl None
    endfor
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

function zotcite#GetReferenceData(type)
    let wrd = zotcite#GetCitationKey()
    if wrd != ''
        if a:type == 'yaml'
            let repl = py3eval('ZotCite.GetYamlRefs(["' . wrd . '"])')
            let repl = substitute(repl, "^references:[\n\r]*", '', '')
            echo repl
            return
        endif
        let repl = py3eval('ZotCite.GetRefData("' . wrd . '")')
        if a:type == 'raw'
            for key in keys(repl)
                echohl Title
                echo key
                echohl None
                if type(repl[key]) == v:t_string
                    echon ': ' . repl[key]
                else
                    echon ': ' . string(repl[key])
                endif
            endfor
        else
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

function zotcite#AddYamlRefs()
    let bigstr = join(getline(1, '$'))
    let bigstr = substitute(bigstr, '.\{-}\(@[A-Z0-9]\{8}#[[:alnum:]à-öø-ÿÀ-ÖØ-ß_:\-]\+\).\{-}', ' \1 ', 'g')
    let bigstr = substitute(bigstr, '\(.*@[A-Z0-9]\{8}#[[:alnum:]à-öø-ÿÀ-ÖØ-ß_:\-]\+\) .*', '\1', 'g')
    let bigstr = substitute(bigstr, '@', '', 'g')
    let rlist = uniq(sort(split(bigstr)))
    exe 'let refs = py3eval("ZotCite.GetYamlRefs(' . string(rlist) . ')")'
    let rlines = split(refs, "\n")
    call append(line('.'), rlines)
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
        let repl = py3eval('ZotCite.SetCollections("' . escape(expand("%:p"), '\\') . '", ' . string(b:zotcite_cllctn) . ')')
        if repl != ''
            call zotcite#warning(repl)
        endif
    endif
endfunction

function zotcite#GlobalInit()
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
    try
        let info = py3eval('ZotCite.Info()')
    catch *
        let g:zotcite_failed = 'Failed to create ZoteroEntries object.'
        call zotcite#warning(g:zotcite_failed)
        let s:zrunning = 0
        return 0
    endtry
    let s:zrunning = 1

    let $Zotcite_tmpdir = info['tmpdir']
    let zotcite_home = info['zotero.py']
    if has('win32')
        let zotcite_home = substitute(zotcite_home, '\(.*\)\\.*', '\1', '')
    else
        let zotcite_home = substitute(zotcite_home, '\(.*\)/.*', '\1', '')
    endif
    if has("win32")
        if $PATH !~ escape(zotcite_home, '\\')
            let $PATH = zotcite_home . ';' . $PATH
        endif
    else
        if $PATH !~ zotcite_home
            let $PATH = zotcite_home . ':' . $PATH
        endif
    endif
    let $RmdFile = expand("%:p")

    call zotcite#GetCollectionName()
    command ZRefs call zotcite#AddYamlRefs()
    command -nargs=1 ZSeek call zotcite#Seek(<q-args>)
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

    " Don't continue if bib file is already in use
    let lines = getline(1, '$')
    for line in lines
        if line =~ '^bibliography:.*\.bib'
            call add(s:log, 'Not enabled for "' . expand('%') . '" (' . line . ')')
            return
        endif
    endfor

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
            exec 'nnoremap <buffer><silent> <Plug>ZCitationInfo :call zotcite#GetReferenceData("ayt")<cr>'
        else
            nnoremap <buffer><silent> <Leader>zi :call zotcite#GetReferenceData("ayt")<cr>
        endif
        if hasmapto('<Plug>ZCitationCompleteInfo', 'n')
            exec 'nnoremap <buffer><silent> <Plug>ZCitationCompleteInfo :call zotcite#GetReferenceData("raw")<cr>'
        else
            nnoremap <buffer><silent> <Leader>za :call zotcite#GetReferenceData("raw")<cr>
        endif
        if hasmapto('<Plug>ZCitationYamlRef', 'n')
            exec 'nnoremap <buffer><silent> <Plug>ZCitationYamlRef :call zotcite#GetReferenceData("yaml")<cr>'
        else
            nnoremap <buffer><silent> <Leader>zy :call zotcite#GetReferenceData("yaml")<cr>
        endif
        if exists('g:zotcite_conceallevel')
            exe 'set conceallevel=' . g:zotcite_conceallevel
        else
            set conceallevel=2
        endif
        setlocal omnifunc=zotcite#CompleteBib
        autocmd BufWritePost <buffer> call zotcite#GetCollectionName()
    endif
endfunction

let s:log = []
let s:zrunning = 0
