if has("nvim-0.10")
    finish
endif

function ZotciteVimBranchWarning(...)
    echohl WarningMsg
    echomsg 'The main branch of Zotcite now requires Neovim >= 0.10. Please, switch to the branch "vim".'
    echohl None
endfunction

function CallVimBranchWarning()
    if &filetype == "markdown" || &filetype == "quarto" || &filetype == "rmd"
	if !exists("s:did_branch_warning")
	    call timer_start(1000, "ZotciteVimBranchWarning")
	    let s:did_branch_warning = 1
	endif
    endif
endfunction

autocmd FileType * call CallVimBranchWarning()
