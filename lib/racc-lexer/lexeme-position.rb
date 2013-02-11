# encoding: utf-8  -- You should see a paragraph character: §
# File: lexeme-position.rb

require_relative "lexer-exceptions"  # Use tailored exception class.

module RaccLexer # This module is used as a namespace

# An object that record the position of a lexeme inside an input stream.
# LexemePosition objects are typically used when the parser reports an error.
# They are meant to be created by a lexer.
class LexemePosition
	# (Absolute) position of the token in the text input stream.
	# The position is measured in character count (which is not necessarily equal to the byte count)
	attr_reader(:offset)

	# Line number where the lexeme occurs(begins).
	attr_reader(:lineno)

	# Position relative to the start of line.
  # Invariant: line_pos <= offset - lineno + 1
	attr_reader(:line_pos)

	# Constructor.
  # [anOffset] See doc. of attribute 'offset'.
  # [aLineNumber] See doc of attribute 'lineno'.
  # [aPositionInLine] See doc of attribute 'lineno'.
  # An exception is raised when the last argument infringes the line_pos invariant.
	def initialize(anOffset, aLineNumber, aPositionInLine)
		@offset, @lineno  = anOffset, aLineNumber  
    @line_pos = valid_line_offset(aPositionInLine)  
	end

public
	# Value semantic implementation: overridden equality operator.
  # For testing purposes it supports comparison with array of integers.
	# return true iff all data members have equal values
	# [another] can be:
	# -a LexemePosition
	# -a Fixnum, then it is assumed to be the offset value.
	# -an Array of integers.
	# -- if it is of size == 1, then it is assumed to be [ offset]
	# -- if it is of size == 2, then it is assumed to be [offset, lineno]
	# -- if it is of size == 3, then it is assumed to be [offset, lineno, line_pos]
	def ==(another)
		return true if self.object_id == another.object_id

		case another
			when LexemePosition
				are_equal = (offset == another.offset) && (lineno == another.lineno) && (line_pos == another.line_pos)

			when Fixnum
				are_equal = (offset == another)

			when Array
				raise InternalLexerError.new("Only integers allowed for token position", nil) unless another.all? {|item| item.kind_of?(Fixnum) }
				case another.size
					when 0
						raise InternalLexerError.new("Empty array may not specify a token position", nil)

					when 1
						are_equal = another[0] == offset

					when 2
						are_equal = (another[0] == offset) && (another[1] == lineno)

					when 3
						are_equal = (another[0] == offset) && (another[1] == lineno) && (another[2] == line_pos)
					else
						raise InternalLexerError.new("Wrong array size for specifying a token position", nil)
				end

			else
				# ...Otherwise rely on standard Ruby implementation
				are_equal = super(another)
		end

		return are_equal
	end
  
private
  # Validation method. 
  # Check that the value of the position in line is in the correct range.
  # Return the valid value, otherwise an exception is raised.
  def valid_line_offset(aPositionInLine)
    raise InternalLexerError.new("Invalid value for position relative to start of in line", nil) if aPositionInLine > (@offset - @lineno + 1)
    
    return aPositionInLine
  end

end # class

end # module

# End of file