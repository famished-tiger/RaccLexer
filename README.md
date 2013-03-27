#RaccLexer#

[Homepage](https://github.com/famished-tiger/RaccLexer)

 
A lexer (aka lexical scanner or tokenizer) has for purpose to break the input text into a sequence of tokens
 and to pass these tokens to the parser. RaccLexer was designed to work with the RACC parser.

##RaccLexer Vision##
It should:
- Become a Ruby gem  
- Provide a DSL (Domain Specific Language) helping you to build and tailor a lexer for your favourite language.
- Associate useful context data with each token passed to the parser (e.g. line number,
approximate token position in source text)  
- Come with a complete set of examples  
- Support languages with off-side rules (like for instance, Python)
 
##Similar projects##
[rexical](https://github.com/tenderlove/rexical) It is a lexer generator.