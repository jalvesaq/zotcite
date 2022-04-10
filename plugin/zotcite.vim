if exists('g:zotcite_failed')
    finish
endif

if exists(':Zinfo') == 2
    finish
endif
let g:zotcite_filetypes = get(g:, 'zotcite_filetypes', ['markdown', 'pandoc', 'rmd', 'quarto'])
augroup zotcite
    autocmd BufNewFile,BufRead * call timer_start(1, "zotcite#Init")
augroup END
command Zinfo call zotcite#info()
command -nargs=1 -complete=file Zodt2md call zotcite#ODTtoMarkdown(<q-args>)
