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

syn match zoteroRefLabel /@[[:digit:][:lower:][:upper:]\u00FF-\uFFFF\-_#]\+/ contains=zoteroRefAnchor
syn region zoteroPCite matchgroup=Operator start=/\[\ze[^\]]\{-}@/ skip=/\\]/ end=/\]/ keepend transparent contains=zoteroCiteKey,markdownItalic,pandocEmphasis
syn match zoteroCiteKey /@\S*[A-Z0-9]\{8}#[:_[:digit:][:lower:][:upper:]\u00FF-\uFFFF]\+/ contains=zoteroHidden,zoteroCiteLocator
syn match zoteroCiteKey /@{\S\{-}}/ contains=zoteroHidden,zoteroCiteLocator
syn match zoteroHidden /[{}]/ conceal
syn match zoteroHidden  /\zs[A-Z0-9]\{8}#/ contained containedin=zoteroCiteKey conceal contains=@NoSpell
syn match zoteroCiteLocator /-\ze@/ contained containedin=zoteroCiteKey
syn match zoteroRefAnchor /@/ contained conceal containedin=zoteroCiteKey

if !hlexists('pandocYAMLHeader')
  syn match mdYamlFieldTtl /^\s*\zs\w*\ze:/ contained
  syn match mdYamlFieldTtl /^\s*-\s*\zs\w*\ze:/ contained
  syn region yamlFlowString matchgroup=yamlFlowStringDelimiter start='"' skip='\\"' end='"' contains=yamlEscape contained
  syn region yamlFlowString matchgroup=yamlFlowStringDelimiter start="'" skip="''"  end="'" contains=yamlSingleEscape contained
  syn match  yamlEscape contained '\\\%([\\"abefnrtv\^0_ NLP\n]\|x\x\x\|u\x\{4}\|U\x\{8}\)'
  syn match  yamlSingleEscape contained "''"
  syn region pandocYAMLHeader matchgroup=mdYamlBlockDelim start=/\%(\%^\|\_^\s*\n\)\@<=\_^-\{3}\ze\n.\+/ end=/^\([-.]\)\1\{2}$/ keepend contains=mdYamlFieldTtl,yamlFlowString
  hi def link mdYamlBlockDelim Delimiter
  hi def link mdYamlFieldTtl Identifier
  hi def link yamlFlowString String
endif

hi default link zoteroRefAnchor Operator
hi default link zoteroCiteLocator Operator
hi default link zoteroRefLabel Label
hi default link zoteroCiteKey Identifier
hi default link zoteroHidden Comment
