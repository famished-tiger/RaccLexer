#RaccLexer#

[Homepage](https://github.com/famished-tiger/RaccLexer)


##What is RaccLexer? 
- RaccLexer is a lexer (aka lexical scanner or tokenizer) designed to work with the [RACC](http://rubygems.org/gems/racc) parser.
- A lexer, in itself, has for purpose to break the input text into a sequence of tokens
 and to pass these tokens to the parser.

##RaccLexer Vision
###It should:  
- Become a Ruby gem  
- Provide a DSL (Domain Specific Language) helping you to build and tailor a lexer for your favourite language.
- Associate useful context data with each token passed to the parser (e.g. line number,
approximate token position in source text)  
- Come with a complete set of examples  
- Support languages with off-side rules (like for instance, Python)
 
##Similar projects##
[rexical](https://github.com/tenderlove/rexical) It is a lexer generator.