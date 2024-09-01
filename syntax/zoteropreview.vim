syntax clear
setlocal conceallevel=2


syn region zAuthor start="{{" end="}}" contains=zConceal keepend
syn region zYear start="{\[" end="\]}" contains=zConceal keepend
syn region zTitle start="{(" end=")}" contains=zConceal keepend
syn region zContainer start="{<" end=">}" contains=zConceal keepend
syn match zConceal "{{" conceal contained
syn match zConceal "{\[" conceal contained
syn match zConceal "{(" conceal contained
syn match zConceal "{<" conceal contained
syn match zConceal "}}" conceal contained
syn match zConceal "]}" conceal contained
syn match zConceal ")}" conceal contained
syn match zConceal ">}" conceal contained

hi link zAuthor Identifier
hi link zYear Number
hi link zTitle Title
hi link zContainer Include
hi link zConceal Conceal
