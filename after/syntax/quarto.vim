if exists('g:zotcite_hl') && g:zotcite_hl == 0
    finish
endif

let g:zotcite_conceallevel = get(g:, 'zotcite_conceallevel', 2)
exe 'setlocal conceallevel=' . g:zotcite_conceallevel

for phl in ['pandocPCite', 'pandocICite', 'pandocCiteKey', 'pandocCiteAnchor', 'pandocCiteLocator', 'pandocNoLabel', 'pandocReferenceLabel']
    if hlexists(phl)
        exe 'syn clear ' . phl
    endif
endfor

syn match zoteroRefAnchor /@/ contained containedin=zoteroRefLabel
syn match zoteroRefLabel /@[[:alnum:]\-à-öø-ÿÀ-ÖØ-ß_#]\+/ contains=zoteroRefAnchor
syn region zoteroPCite start=/\[-\{0,1}@/ skip=/[^\]]/ end=/\]/ keepend contains=zoteroCiteKey,zoteroVisible,zoteroHidden,zoteroCiteLocator,@NoSpell
syn match zoteroCiteLocator /[\[\]]/ contained containedin=zoteroPCite
syn match zoteroCiteKey /-\{0,1}@[A-Z0-9]\{8}#[[:alnum:]à-öø-ÿÀ-ÖØ-ß_]\+/ contains=zoteroVisible,zoteroHidden
syn match zoteroVisible /[[:alnum:]à-öø-ÿÀ-ÖØ-ß_]\+/ contained containedin=zoteroCiteKey
syn match zoteroHidden  /@[A-Z0-9]\{8}#/ contained containedin=zoteroCiteKey conceal

" syn match zoteroICite /-\{0,1}@[#[:alnum:]à-öø-ÿÀ-ÖØ-ß_]\+/ contains=zoteroCiteKey,@NoSpell transparent

hi default link zoteroRefLabel Label
hi default link zoteroRefAnchor Operator
hi default link zoteroCiteLocator Operator
hi default link zoteroCiteKey Operator
hi default link zoteroHidden Comment
hi default link zoteroVisible Identifier
