if exists('g:zotcite_failed')
    finish
endif

let g:zotcite_filetypes = get(g:, 'zotcite_filetypes', ['markdown', 'pandoc', 'rmd'])

augroup zotcite
    autocmd BufNewFile,BufRead * call zotcite#Init()
augroup END
