# encoding: utf-8  -- You should see a paragraph character: §
# File: lexer-exceptions.rb
# Purpose: implementation lexer-specific exception classes

module RaccLexer  # This module is used as a namespace

# General exception class for errors detected by the lexer.
# These exceptions should be captured by the parser.
class LexerError < StandardError

	# Constructor.
	# [anErrorMessage]	An error message text.
	def initialize(anErrorMessage)
		super(anErrorMessage)
	end
end # class


# A specialized exception class reserved for errors detected while
# setting up the lexer.
# The lexer setup groups all activites performed before the scanning starts.
class LexerSetupError < LexerError
end # class

# A specialised exception class that indicates that an issue in the rules provided to the lexer occurred.
class LexerRuleError < LexerError
end # class



# An exception class for errors detected while the lexer
# was scanning/analyzing the input stream.
class LexingError < LexerError
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
class InternalLexerError < LexingError
  MessagePrefix = "Internal error: "

	# Constructor.
	# [anErrorMessage]	An error message text
	# [aPosition]	A TokenPosition object that specifies where the token is located in the input text.
	def initialize(anErrorMessage, aPosition)
		super(MessagePrefix + anErrorMessage, aPosition)
	end

end # class



# A specialised exception class that indicates that the input text
# doesn't comply to the rules known to the lexer
class LexicalError < LexingError
end # class

end # module

# End of file