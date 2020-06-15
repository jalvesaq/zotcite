
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
            if &filetype == "rmd"
                if len(glob(expand("%:p:h") . '/*.bib', 0, 1)) > 0
                    echo "There is a .bib file in this directory. Omni completion might not work."
                endif
            endif
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
        while idx > 0
            if line[idx] =~ '\w'
                let idx -= 1
            elseif idx > 1 && line[idx-1] >= "\xc2" && line[idx-1] <= "\xdf" && line[idx] >= "\x80" && line[idx] <= "\xbf"
                " UTF-8 character (two bytes)
                let idx -= 2
            elseif idx > 2 && line[idx-2] >= "\xe0" && line[idx-2] <= "\xef" && line[idx-1] >= "\x80" && line[idx-1] <= "\xbf" && line[idx] >= "\x80" && line[idx] <= "\xbf"
                " UTF-8 character (three bytes)
                let idx -= 3
            else
                break
            endif
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

function zotcite#getmach(key)
    let citeptrn = substitute(a:key, ' .*', '', '')
    let lines = py3eval('ZotCite.GetMatch("'. citeptrn .'", "'. escape(expand("%:p"), '\\') .'")')
    let resp = []
    for line in lines
        let tmp = split(line, "\x09")
        let item = {'key': substitute(tmp[0], '#.*', '', ''), 'author': tmp[1]}
        if tmp[2] =~ '^([0-9][0-9][0-9][0-9]) '
            let item['year'] = substitute(tmp[2], '^(\([0-9][0-9][0-9][0-9]\)) .*', '\1', '')
            let item['ttl'] = substitute(tmp[2], '^([0-9][0-9][0-9][0-9]) ', '', '')
        elseif tmp[2] =~ '^() '
            let item['year'] = ''
            let item['ttl'] = substitute(tmp[2], '^() ', '', '')
        else
            let item['year'] = ''
            let item['ttl'] = tmp[2]
        endif
        call add(resp, item)
    endfor
    if len(resp) == 0
        echo 'No matches found.'
    endif
    return resp
endfunction

function zotcite#printmatches(mtchs, prefix)
    let idx = 0
    for mt in a:mtchs
        let idx += 1
        let room = &columns - len(mt['year']) - len(mt['author']) - 3
        if a:prefix
            echo idx . ': '
            echohl Identifier
            echon mt['author'] . ' '
            let room = room - len(idx) - 2
        else
            echohl Identifier
            echo mt['author'] . ' '
        endif
        if len(mt['ttl']) > room
            let mt['ttl'] = substitute(mt['ttl'], '^\(.\{'.room.'}\).*', '\1', '')
        endif
        echohl Number
        echon  mt['year'] . ' '
        echohl Title
        echon mt['ttl']
        echohl None
    endfor
endfunction

function zotcite#Seek(key)
    let mtchs = zotcite#getmach(a:key)
    call zotcite#printmatches(mtchs, 0)
endfunction

function zotcite#GetNote(key)
    let zotkey = zotcite#FindCitationKey(a:key)
    if zotkey != ''
        let repl = py3eval('ZotCite.GetNotes("' . zotkey . '")')
        if repl == ''
            redraw
            echo 'No note found.'
        else
            call append('.', split(repl, "\n"))
        endif
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

function zotcite#GetYamlRef()
    let wrd = zotcite#GetCitationKey()
    if wrd != ''
        let repl = py3eval('ZotCite.GetYamlRefs(["' . wrd . '"])')
        let repl = substitute(repl, "^references:[\n\r]*", '', '')
        if repl == ''
            call zotcite#warning('Citation key not found')
        else
            echo repl
        endif
    endif
endfunction

function zotcite#GetReferenceData(type)
    let wrd = zotcite#GetCitationKey()
    if wrd != ''
        let repl = py3eval('ZotCite.GetRefData("' . wrd . '")')
        if len(repl) == 0
            call zotcite#warning('Citation key not found')
            return
        endif
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

function zotcite#TranslateZPath(strg)
    let fpath = a:strg
    if a:strg =~ ':attachments:'
	" The user has set Edit / Preferences / Files and Folders / Base directory for linked attachments
	if g:zotcite_attach_dir == ''
	    call zotcite#warning('Attachments dir is not defined')
        else
            let fpath = substitute(a:strg, '.*:attachments:', '/' . g:zotcite_attach_dir . '/', '')
	endif
    elseif a:strg =~ ':/'
	" Absolute file path
	let fpath = substitute(a:strg, '.*:/', '/', '')
    elseif a:strg =~ ':storage:'
	" Default path
	let fpath = g:zotcite_data_dir . substitute(a:strg, '\(.*\):storage:', '/storage/\1/', '')
    endif
    if !filereadable(fpath)
        call zotcite#warning('Could not find "' . fpath . '"')
        let fpath = ''
    endif
    return fpath
endfunction

function zotcite#GetPDFPath(zotkey)
    let repl = py3eval('ZotCite.GetAttachment("' . a:zotkey . '")')
    if len(repl) == 0
        call zotcite#warning('Got empty list')
        return
    endif
    if repl[0] == 'nOaTtAChMeNt'
        redraw
        call zotcite#warning('Attachment not found')
    elseif repl[0] == 'nOcItEkEy'
        redraw
        call zotcite#warning('Citation key not found')
    else
        if len(repl) == 1
            return zotcite#TranslateZPath(repl[0])
        else
            let idx = 1
            for at in repl
                echohl Number
                echo idx
                echohl None
                echon  '. ' . substitute(zotcite#TranslateZPath(at), '.*storage:', '', '')
                let idx += 1
            endfor
            let idx = input('Your choice: ')
            if idx != '' && idx >= 1 && idx <= len(repl)
                return zotcite#TranslateZPath(repl[idx - 1])
            endif
        endif
    endif
    return ''
endfunction

function zotcite#FindCitationKey(str)
    let mtchs = zotcite#getmach(a:str)
    if len(mtchs) == 0
        return ''
    endif
    call zotcite#printmatches(mtchs, 1)
    let idx = input('Your choice: ')
    if idx == "" || idx <= 0 || idx > len(mtchs)
        return ''
    endif
    return mtchs[idx - 1]['key']
endfunction

function zotcite#OpenAttachment()
    let zotkey = zotcite#GetCitationKey()
    let fpath = zotcite#GetPDFPath(zotkey)
    if fpath != ''
        call system(s:open_cmd . ' "' . fpath . '" &')
    endif
endfunction

function zotcite#GetPDFNote(key)
    let zotkey = zotcite#FindCitationKey(a:key)
    let fpath = zotcite#GetPDFPath(zotkey)
    if fpath == ''
        return
    endif
    let repl = py3eval('ZotCite.GetRefData("' . zotkey . '")')
    let citekey = " '@" . zotkey . '#' . repl['citekey'] . "' "
    let page1 = 1
    if has_key(repl, 'pages') && repl['pages'] =~ '[0-9]-'
        let page1 = substitute(repl['pages'], '-.*', '', '')
    endif
    let notes = system("pdfnotes '" . fpath . "'" . citekey . page1)
    call append(line('.'), split(notes, '\n'))
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

function zotcite#SetPath()
    if has("win32")
        if $PATH !~ escape(s:zotcite_home, '\\')
            let $PATH = s:zotcite_home . ';' . $PATH
        endif
    else
        if $PATH !~ s:zotcite_home
            let $PATH = s:zotcite_home . ':' . $PATH
        endif
    endif
endfunction

function zotcite#ODTtoMarkdown(odt)
    call zotcite#SetPath()
    let mdf = system("odt2md '" . a:odt . "'")
    exe 'tabnew ' . mdf
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
    catch
        let g:zotcite_failed = 'Failed to create ZoteroEntries object.'
        call zotcite#warning(g:zotcite_failed)
        let s:zrunning = 0
        return 0
    endtry
    let s:zrunning = 1

    let $Zotcite_tmpdir = info['tmpdir']
    let g:zotcite_data_dir = info['data dir']
    let g:zotcite_attach_dir = info['attachments dir']

    call zotcite#SetPath()
    let $RmdFile = expand("%:p")

    command Zrefs call zotcite#AddYamlRefs()
    command -nargs=1 Zseek call zotcite#Seek(<q-args>)
    command -nargs=1 Znote call zotcite#GetNote(<q-args>)
    command -nargs=1 Zpdfnote call zotcite#GetPDFNote(<q-args>)

    " 2019-03-17:
    command ZRefs call zotcite#warning('The command :ZRefs was renamed as :Zrefs') | delcommand ZRefs
    command -nargs=1 ZSeek call zotcite#warning('The command :ZSeek was renamed as :Zseek') | delcommand ZSeek
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
            exec 'nnoremap <buffer><silent> <Plug>ZOpenAttachment :call zotcite#OpenAttachment()<cr>'
        else
            nnoremap <buffer><silent> <Leader>zo :call zotcite#OpenAttachment()<cr>
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
            exec 'nnoremap <buffer><silent> <Plug>ZCitationYamlRef :call zotcite#GetYamlRef()<cr>'
        else
            nnoremap <buffer><silent> <Leader>zy :call zotcite#GetYamlRef()<cr>
        endif
        if exists('g:zotcite_conceallevel')
            exe 'set conceallevel=' . g:zotcite_conceallevel
        else
            set conceallevel=2
        endif
        " Let Nvim-R control the omni completion
        if !exists('b:rplugin_non_r_omnifunc')
            setlocal omnifunc=zotcite#CompleteBib
        endif
        call zotcite#GetCollectionName()
        autocmd BufWritePost <buffer> call zotcite#GetCollectionName()
    endif
endfunction

let s:zotcite_home = expand('<sfile>:h:h') . '/python3'
let s:log = []
let s:zrunning = 0
