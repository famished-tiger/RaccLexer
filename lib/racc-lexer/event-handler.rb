# File: event-handler.rb

module RaccLexer # This module is used as a namespace

# In essence, an event handler is a pair: pattern, action. It specifies the action to launch
# when the current Lexer input matches the pattern.
class EventHandler
	# A character or regular expression that will trigger the action if the current input matches this pattern
	attr_reader(:pattern)
	
	# The action to trigger when the pattern is met.
	attr_reader(:action)
	
	# Constructor.
	# [thePattern]	A String or a Regexp.
	# [theAction] A LexerAction object.
	def initialize(thePattern, theAction)
		@pattern = validated_pattern(thePattern)
		@action = validated_action(theAction)
	end
	
public
	# Return true iff the given text matches the pattern
	def matching?(aText)
		result = case pattern
			when String
				(aText == pattern)	# Exact match?
				
			when Regexp
				(aText =~ pattern)
		end
		
		return result
	end
	
	# Apply the action for the given Lexer.
	# The result should be a token formatted as requested by the parser.
	def apply_to(aLexer)
		return action.apply_to(aLexer)
	end
	
	# Returns the list of all possible actions to be executed in case of a match.
	def all_actions()
		return action.children.unshift(action)
	end

private
	# Return the given pattern after its validation
	# A InternalLexerError exception is raised if the argument does not meet the validation.
	def validated_pattern(aPattern)
		raise InternalLexerError, "Pattern argument must be a String or a Regexp." unless [Regexp, String].include? aPattern.class()
	
		return aPattern
	end
	
	# Return the given pattern after its validation
	# A TypeError exception is raised if the argument does not meet the validation.	
	def validated_action(anAction)
		raise TypeError, "#{anAction} is not a LexerAction" unless anAction.kind_of?(LexerAction)
		
		return anAction
	end
	
	
	
end # class

end # module
# End of file