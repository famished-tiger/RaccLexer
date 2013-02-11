# encoding: utf-8  -- You should see a paragraph character: §
# File: lexer-exceptions.rb
# Purpose: implementation lexer-specific exception classes

module RaccLexer  # This module is used as a namespace

# Specialised exception class for errors raised by the lexer.
# These exceptions should be captured by the parser.
class LexerError < StandardError
	# Record the token position that caused the error.
	attr_reader(:position)

	# Constructor.
	# [anErrorMessage]	An error message text
	# [aPosition]	A TokenPosition object that specifies where the token is located in the input text.
	def initialize(anErrorMessage, aPosition)
		super(anErrorMessage)
		@position = aPosition
	end
end # class


# A specialised exception class that indicates that an anomaly in the lexer's code occurred.
class InternalLexerError < LexerError
end # class

# A specialised exception class that indicates that an issue in the rules provided to the lexer. 
class LexerRuleError < LexerError
end # class

# A specialised exception class that indicates that the input text
# doesn't comply to the rules known to the lexer
class LexicalError < LexerError
end # class

end # module

# End of file