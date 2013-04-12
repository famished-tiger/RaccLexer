# encoding: utf-8  -- You should see a paragraph character: §
# File: token.rb

require_relative 'lexeme-position' # This class is used to store the position of the token/lexeme in the input text.


module RaccLexer # This module is used as a namespace

# Encapsulates the data returned by the Lexer to the parser.
class Token
	# The original text representation of the token as it appears in the input text
	attr_reader(:lexeme)

	# The 'normalised' value of the token. In many case, it is the same as the lexeme text
	attr_reader(:value)

	# The position of the token (useful for error reporting) implemented as a TokenPosition object.
	attr_reader(:position)


	# Constructor.
  # [theValue]. See doc of 'value' attribute. 
  # [theLexeme]. See doc of 'lexeme' attribute.
  # [aPosition]. See doc of 'position' attribute.
  # Example:
  #  Token.new(1234, '1234', LexemePosition.new(10, 2, 3))
  #  The lexeme is '1234', the value is the integer 1234,
  #  The lexeme position is: 10th character in the input stream,
  #  column 3 in line 2.
	def initialize(theValue, theLexeme, aPosition)
		@value, @lexeme, @position =  theValue, theLexeme, aPosition
	end

public
	# Overridden equality operator.
  # [anotherToken] can be:
  #  -a Token. comparison is true when all attributes have the same values.
	#  -a String. => equality when another == self.value
	#  -a Fixnum. => another == self.offset
	#  -an Array. A couple like [value/lexeme, a position array].
	def ==(anotherToken)
		are_equal = case anotherToken
			when String
				anotherToken == value
        
			when Token
				(lexeme == anotherToken.lexeme) && (value == anotherToken.value) && (position == anotherToken.position)
        
			when Array	# [value/lexeme, a position array]
				(value == anotherToken.first) && (position == anotherToken.last)
			else
				# Fall back on default Ruby implementation...
				super(anotherToken)
		end

		return are_equal
	end

end # class

end # module

# End of file