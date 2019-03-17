if exists('g:zotcite_hl') && g:zotcite_hl == 0
    finish
endif

let g:zotcite_conceallevel = get(g:, 'zotcite_conceallevel', 2)
exe 'setlocal conceallevel=' . g:zotcite_conceallevel

if exists("b:current_syntax") && b:current_syntax == "pandoc"
    " Try to adapt to pandoc syntax
    hi pandocCiteAnchor NONE
    hi pandocCiteKey NONE
    hi pandocCiteLocator NONE
    hi pandocICite NONE
    hi pandocPCite NONE
    hi zoteroHashTag NONE
    hi zoteroKey NONE

    syn match zoteroKey /-\{0,1}@[A-Z0-9]\{8}/ containedin=pandocPCite,pandocICite conceal
    syn match pandocCiteKey /#[[:alnum:]à-öø-ÿÀ-ÖØ-ß_\-]\+/ containedin=pandocPCite,pandocICite contains=@NoSpell,zoteroHashTag display
    syn match zoteroHashTag /#/ containedin=pandocCiteKey conceal
    syn match pandocCiteAnchor /[-\{0,1}@]/ contained containedin=pandocCiteKey display transparent
    syn match pandocCiteLocator /[\[\]]/ contained containedin=pandocPCite,pandocICite
    syn match pandocPCite /\[[^]]*@[A-Z0-9]\{8}#[^]]*\]/ contains=pandocEmphasis,pandocStrong,pandocLatex,pandocCiteKey,@Spell,pandocAmpersandEscape
    syn match pandocICite /-\{0,1}@[A-Z0-9]\{8}#[[:alnum:]à-öø-ÿÀ-ÖØ-ß_\-]\+/ contains=zoteroKey,pandocCiteKey,@Spell display


    hi default link zoteroKey Comment
    hi default link zoteroHashTag Comment
    hi default link pandocPCite Operator
    hi default link pandocICite Operator
    hi default link pandocCiteAnchor Operator
    hi default link pandocCiteLocator Operator
else
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
endif
