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
syn match zoteroRefLabel /@[[:digit:][:lower:][:upper:]\u00FF-\uFFFF\-_#]\+/ contains=zoteroRefAnchor

syn region zoteroPCite start=/\[[^\].]\{-}@[A-Z0-9]\{8}#/ skip=/\\]/ end=/\]/ transparent keepend contains=zoteroCiteKey,zoteroCiteLocator,markdownItalic,pandocEmphasis
syn match zoteroCiteLocator /[\[\]]/ contained containedin=zoteroPCite

syn match zoteroCiteKey /-\{0,1}@[A-Z0-9]\{8}#[[:digit:][:lower:][:upper:]\u00FF-\uFFFF_]\+/ contains=zoteroVisible,zoteroHidden
syn match zoteroHidden  /@[A-Z0-9]\{8}#/ contained containedin=zoteroCiteKey conceal contains=@NoSpell
syn match zoteroVisible /#[[:digit:][:lower:][:upper:]\u00FF-\uFFFF_]\+/ contained containedin=zoteroCiteKey contains=@NoSpell

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
hi default link zoteroVisible Identifier
