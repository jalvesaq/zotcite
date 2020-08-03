if exists('g:zotcite_hl') && g:zotcite_hl == 0
    finish
endif

let g:zotcite_conceallevel = get(g:, 'zotcite_conceallevel', 2)
exe 'setlocal conceallevel=' . g:zotcite_conceallevel

syn match zoteroCiteKey /-\{0,1}@[#[:alnum:]à-öø-ÿÀ-ÖØ-ß_]\+/ contains=zoteroCiteAnchor,zoteroVisible,zoteroHidden
syn match zoteroVisible /[[:alnum:]à-öø-ÿÀ-ÖØ-ß_]\+/ contained containedin=zoteroCiteKey
syn match zoteroHidden  /@[A-Z0-9]\{8}#/ contained containedin=zoteroCiteKey conceal

syn match zoteroCiteLocator /[\[\]]/ contained containedin=zoteroPCite
syn region zoteroPCite start=/\[-\{0,1}@/ skip=/[^\]]/ end=/\]/ keepend contains=zoteroCiteKey,zoteroCiteLocator,@NoSpell
syn match zoteroICite /-\{0,1}@[#[:alnum:]à-öø-ÿÀ-ÖØ-ß_]\+/ contains=zoteroCiteKey,@NoSpell transparent

hi default link zoteroCiteLocator Operator
hi default link zoteroCiteKey Operator
hi default link zoteroCiteAnchor Operator
hi default link zoteroHidden Comment
hi default link zoteroVisible Identifier
