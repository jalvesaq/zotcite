if exists('g:zotcite_hl') && g:zotcite_hl == 0
    finish
endif

let g:zotcite_conceallevel = get(g:, 'zotcite_conceallevel', 2)
exe 'setlocal conceallevel=' . g:zotcite_conceallevel

hi pandocCiteAnchor NONE
hi pandocCiteKey NONE
hi pandocCiteLocator NONE
hi pandocICite NONE
hi pandocPCite NONE
hi zoteroHashTag NONE
hi zoteroKey NONE

syn match zoteroKey /@[A-Z0-9]\{8}/ containedin=pandocPCite,pandocICite conceal
syn match pandocCiteKey /#[[:alnum:]à-öø-ÿÀ-ÖØ-ß_:\-]\+/ containedin=pandocPCite,pandocICite contains=@NoSpell,zoteroHashTag display
syn match zoteroHashTag /#/ containedin=pandocCiteKey conceal
syn match pandocCiteAnchor /[-@]/ contained containedin=pandocCiteKey display transparent
syn match pandocCiteLocator /[\[\]]/ contained containedin=pandocPCite,pandocICite
syn match pandocPCite /\[[^]]*@[A-Z0-9]\{8}#[^]]*\]/ contains=pandocEmphasis,pandocStrong,pandocLatex,pandocCiteKey,@Spell,pandocAmpersandEscape
syn match pandocICite /-*@[A-Z0-9]\{8}#[[:alnum:]à-öø-ÿÀ-ÖØ-ß_:\-]\+/ contains=zoteroKey,pandocCiteKey,@Spell display


hi default link zoteroKey Comment
hi default link zoteroHashTag Comment
hi default link pandocPCite Operator
hi default link pandocICite Operator
hi default link pandocCiteAnchor Operator
hi default link pandocCiteLocator Operator
" Set the default highlight group to Identifier because the @ symbol is being concealed
hi default link pandocCiteKey Identifier

