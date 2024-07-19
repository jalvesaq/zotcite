if has("nvim-0.10")
    finish
endif

function ZotciteVimBranchWarning(...)
    echohl WarningMsg
    echomsg 'The main branch of Zotcite now requires Neovim >= 0.10. Please, switch to the branch "vim".'
    echohl None
endfunction

function CallVimBranchWarning()
    if &filetype == "markdown" || &filetype == "quarto" || &filetype == "rmd" || &filetype == "vimwiki"
	if !exists("s:did_branch_warning")
	    let s:did_branch_warning = 1
	    call timer_start(1000, "ZotciteVimBranchWarning")
	endif
    endif
endfunction

autocmd FileType * call CallVimBranchWarning()
