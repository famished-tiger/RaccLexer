# File: lexer-action.rb

require_relative '../abstract-method'

module RaccLexer # This module is used as a namespace

# Abstract class. A tokenizing action is a behaviour that a Lexer should follow
# when given character(s) or pattern was detected at the current position.
# Actions are triggered when the condition of a tokenizer rule is fulfilled.
# The result of the action is typically a token in the format requested by the parser;
# For RACC-generated parser, tokens are of the form [token type, lexeme]
# or [false, '$'] for the end of token stream marker.
class LexerAction
public
	# Return all (sub)-actions that can possibly be executed when executing this one.
	# Default implementation: returns an empty array.
	def children()
		return []
	end
	
protected
	# Apply the action to the Lexer.
	# Return the token as a result of the applied action.
	# Example: RACC-generated parser expects tokens to be in the form:
	# [token type, lexeme] or [false, '$'] for the end of the token stream.
	def apply_to(aLexer) abstract_method
	end
	
end # class


# Specialised tokenizing action that sends the specified message 
# to a given Lexer when the action is applied to it.
class SendMessageAction < LexerAction
	# The message to send (= the method of the Lexer to call).
	attr_reader(:message)
	
	# The message arguments
	attr_reader(:args)

	# Constructor
  # [theMessage] method name (as a Symbol) of the Lexer. 
  # [theArgs] Zero of more arguments for the message
	def initialize(theMessage, *theArgs)
		@message = validated_message(theMessage)
		@args = theArgs
	end
	
public
	# Apply the action to the Lexer.
  # Return the result of the method invoked when message is sent to the Lexer.
	#-Pre-condition:
	#-- aLexer.respond_to? message is true
	def apply_to(aLexer)
		return aLexer.send(message, *args)
	end

private
	# Return the given message after validation
	def validated_message(theMessage)
		raise TypeError, "#{theMessage} is not a symbol" unless theMessage.kind_of?(Symbol)
		
		return theMessage
	end
end # class


# Specialised tokenizing action that enqueues a recognized token.
class EnqueueToken < LexerAction
	# The token type that corresponds to the tokenized text (lexeme).
	# It should be a Symbol or a single character.
	# By convention, the token type for the end of stream marker is the Symbol :EOS
	attr_reader(:token_type)
	
	# Constructor
  # [theTokenType] See doc of 'token_type' attribute.
	def initialize(theTokenType)
		@token_type = validated_token_type(theTokenType)
	end	

public
	# Apply the action to the Lexer.
	# Returns the created token in format required by a RACC-generated parser:
	#- a couple in the form: [token type, lexeme]
	#-Pre-conditions: 
	#-- aLexer has the method enqueue_token
	def apply_to(aLexer)
		token = aLexer.enqueue_token(token_type)
    
		return token
	end
	
private
	# Return the given token type after validation
	def validated_token_type(theTokenType)
		raise TypeError, "#{theTokenType} is not a symbol nor a string" unless [Symbol, String].include? theTokenType.class
		
		return theTokenType
	end	
end # class


# Specialised action that applies a (sub)rule with specified name to a given Lexer.
class ApplySubrule < LexerAction
	# The name (as a Symbol) of the sub-rule to apply.
	attr_reader(:rulename)

	# Constructor.
  #[theSubRulename] A Symbol, see doc of attribute 'rulename'.
	def initialize(theSubRulename)
		@rulename = validated_rulename(theSubRulename)
	end
	
public
	# Apply the action to the given Lexer.
	#-Pre-condition:
	#-- aLexer has the method 'find_rule' that returns the set of Lexer rules.
	def apply_to(aLexer)
		subrule = aLexer.find_rule(rulename)
		return subrule.apply_to(aLexer)
	end
	
private
	# Return the given sub-rule name after validation
	# An TypeError exception is raised if the argument does not meet the validation.
	def validated_rulename(theSubRulename)
		raise TypeError, "#{theSubRulename} is not a symbol" unless theSubRulename.kind_of?(Symbol)
		
		return theSubRulename
	end
end # class


# Specialised tokenizing action that moves the scanning position back by the length of the lexeme.
# The lexeme is cleared. In other words, it works as if the lexeme in the input text wasn't yet scanned.
class UndoScan < LexerAction
	
public
	# Apply the action to Lexer.
	#-Pre-condition:
	#-- aLexer has the method 'unscan' that returns the set of Lexer rules.
  # TODO: check return value
	def apply_to(aLexer)
		return aLexer.undo_scan()
	end
	
end # class


# Specialised tokenizing action that clears the current lexeme.
class Clear < LexerAction
	
public
	# Apply the action to Lexer.
	#-Pre-condition:
	#-- aLexer has an attribute lexeme
	def apply_to(aLexer)
		return aLexer.lexeme.clear()
	end
	
end # class


# Weird tokenizing action that changes the token type of the last enqueued token provided
# its current token type is the same as the before token type.
# TODO: is it needed?
class MutateToken < LexerAction
	# The original token type (before mutation)
	attr_reader(:type_before)
	
	# The token type after mutation
	attr_reader(:type_after)
	
public
	# Constructor.
	# [theTypeBefore]	String or Symbol for the token type
	# [theTypeAfter]	String or Symbol for the token type
	def initialize(theTypeBefore, theTypeAfter)
		@type_before, @type_after = theTypeBefore, theTypeAfter
	end


	# Apply the action to Lexer.
	#-Pre-condition:
	#-- aLexer has the method 'queue' that returns the token queue.
	def apply_to(aLexer)
		queue = aLexer.queue		
		unless queue.empty?
			last_token = queue.first
			if last_token.first == type_before
				last_token[0] = type_after
			end
		end
		
		return last_token
	end
	
end # class


# An action that consists of a sequence of child actions.
class ActionSequence < LexerAction
	# The list of actions to run in sequence
	attr_reader(:sequence)

	# Constructor.
	# [childrenActions] an Array of actions to execute in sequence
	def initialize(childrenActions)
		raise LexerSetupError, "Empty action list." if childrenActions.empty?
		childrenActions.all? { |anAction| validated_action(anAction) }
		@sequence = childrenActions
	end
	
public
	# Return all (sub)actions that can possibly be executed when executing this one.
	# Default implementation: return the alternative actions (and their children).
	def children()
		descendents = sequence.map() do |aChild|
			indirectChildren = aChild.children
			
			( indirectChildren.empty? ? aChild : indirectChildren.unshift(aChild) )
		end

		return descendents.flatten()
	end

	# Strategy method. Apply the children actions to Lexer.
	def apply_to(aLexer)
		result = sequence.each { |anAction| anAction.apply_to(aLexer) }
		return result
	end
	
private	
	# Return the given pattern after its validation
	# An LexerSetupError exception is raised if the argument does not meet the validation.	
	def validated_action(anAction)
		raise LexerSetupError, "#{anAction} is not a LexerAction" unless anAction.kind_of?(LexerAction)
		
		return anAction
	end
end # class


# Abstract specialisation of a tokenizing action that selects conditionally an action.
# The selected action is determined by the outcome of the comparison of the pattern with the input text.
class ChoiceAction < LexerAction
	include AbstractMethod
	
	# The pattern that defines the condition. If the input text matches the pattern, 
	# then the first action from the alternative is taken.
	attr_reader(:pattern)
	
	# The action(s) to select.
  # The first action is selected when the pattern matching succeeds.
  # Otherwise the second action is taken.
	attr_reader(:alternative)

	# Constructor
	def initialize(aPattern, matchAction, no_matchAction = nil)
		@pattern = validated_pattern(aPattern)
		@alternative = []
		alternative << validated_action(matchAction)
		
		action2 = no_matchAction.nil? ? nil : validated_action(no_matchAction)
		alternative << action2
	end
	
public
	# Return all (sub)actions that can possibly be executed when executing this one.
	# Default implementation: return the alternative actions (and their children).
	def children()
		descendents = alternative.map() do |aChild|
			if aChild.nil?
				nil
			else
				indirectChildren = aChild.children
			
				( indirectChildren.empty? ? aChild : indirectChildren.unshift(aChild) )
			end
		end

		return descendents.flatten.compact()
	end

	# Strategy method. Apply the action to Lexer.
	def apply_to(aLexer)
		criterion = comparison(aLexer)
		action = criterion ? alternative.first : alternative.last
		return action.apply_to(aLexer) unless action.nil?
	end
	
protected
	# Abstract method. Purpose: select the action based on the outcome the comparison between the pattern
	# and the input. The result of the comparison is returned (i.e. true iff there is a match).
	# [theLexer] the Lexer upon which the input text to compare is requested
	def comparison(theLexer) abstract_method
	end
	
private
	# Return the given pattern after its validation
	# A LexerSetupError exception is raised if the argument does not meet the validation.
	def validated_pattern(aPattern)
		raise LexerSetupError, "Pattern argument must be a String or a Regexp." unless [Regexp, String].include? aPattern.class()
	
		return aPattern
	end
	
	# Return the given pattern after its validation
	# A TypeError exception is raised if the argument does not meet the validation.	
	def validated_action(anAction)
		raise TypeError, "#{anAction} is not a LexerAction" unless anAction.kind_of?(LexerAction)
		
		return anAction
	end
end # class


# Specialisation of a selection action that selects conditionally an action.
# The selected action is determined by the outcome of the comparison of the pattern 
# with a lexeme text.
# The Lexer must respond to the message:
#-lexeme.
class ChoiceOnLexeme < ChoiceAction

	# Constructor
	def initialize(aPattern, matchAction, no_matchAction = nil)
		super(aPattern, matchAction, no_matchAction)
	end
	
protected
	# Re-defined method. Purpose: select the action based on the outcome the comparison between the pattern
	# and the current lexeme from the Lexer. The result of the comparison is returned (i.e. true iff there is a match).
	# The comparison is performed between the pattern and the Lexer lexeme.
	# [theLexer] the Lexer that provides the input text
	def comparison(theLexer)
		result = case pattern
			when String
				theLexer.lexeme == pattern	# Exact match
				
			when Regexp
				theLexer.lexeme =~ pattern	# Approximate match
		end
		
		return result
	end	
	
end # class

# Specialisation of a selection action that selects conditionally an action.
# The selected action is determined by the outcome of the comparison of the pattern with the input text.
# The Lexer must respond to the message:
#-scan.
class ChoiceOnLookahead < ChoiceAction

	# Constructor
	def initialize(aPattern, matchAction, no_matchAction = nil)
		super(aPattern, matchAction, no_matchAction)
	end
	
protected	
	# Re-defined method. Purpose: select the action based on the outcome the comparison between the pattern
	# and a lookahead text from the Lexer. The result of the comparison is returned (i.e. true iff there is a match).
	# The comparison is performed between the pattern and the Lexer lookahead.
	# [theLexer] the Lexer that provides the input text
	def comparison(theLexer)
		result = case pattern
			when String
				raise InternalLexerError.new("Not yet implemented", nil) #theLexer.lexeme == pattern	# Exact match
				
			when Regexp
				theLexer.scan(pattern)	# Approximate match
		end
		
		return result
	end	
	
end # class


# Specialised Lexer action that change the state of the Lexer then run another Lexer action
class ChangeState < SendMessageAction
	# The message to send
	attr_reader(:message)
	
	# The message arguments
	attr_reader(:args)
	
	# The Lexer action to execute after the transition occurred.
	attr_reader(:post_action)

	# Constructor.
	# [theMessage]	Symbolic name of the method to induce the state change
	# [aDestinationState] The state to reach
	# [aPostAction] The Lexer action to perform after the state change
	def initialize(theMessage, aDestinationState, aPostAction)
		super(theMessage, aDestinationState)
		
		@post_action = validated_action(aPostAction)
	end
	
public
	# Method re-definition. Apply the actions to the Lexer.
	# First the state change is done, then
	# the post-action is applied to the Lexer
	# The return value is the result of the post-action
	def apply_to(aLexer)
		super(aLexer)	# This should induce a state-change
		return post_action.apply_to(aLexer)
	end
	
	# Return the destination state.
	def to_state()
		return args.first
	end
	
	# Method re-definition. Return the (sub) action that can possibly be executed when executing this one.
	# Default implementation: returns the post-action.
	def children()
		if post_action.children.empty?
			descendents = [ post_action ]
		else
			raw_descendents = post_action.children.unshift(post_action)
			descendents = raw_descendents.flatten()
		end

		return descendents
	end		

private
		# An TypeError exception is raised if the argument does not meet the validation.	
	def validated_action(anAction)
		raise TypeError, "#{anAction} is not a LexerAction" unless anAction.kind_of?(LexerAction)
		
		return anAction
	end
end # class


# A tokenizing action that defines a strict sequence of child actions.
# To each child action there is a pattern associated with it.
# The action is performed under the condition that the lookahead text matches the pattern.
# If a discrepancy arises between a pattern and the input text, then an unknown_token error is reported
class ConditionalActionSequence < LexerAction
	
	# An Array with couples of the form [pattern, action]
	attr_reader(:sequence)

	# Constructor
	# [patternActionPairs] An Array with couples of the form [pattern, action]
	def initialize(patternActionPairs)
		@sequence = []
		patternActionPairs.each do |aCouple|
			(aPattern, anAction) = aCouple
			validated_pattern(aPattern)
			validated_action(anAction)
			sequence << aCouple
		end
	end
	
public
	# Return all (sub)actions that can possibly be executed when executing this one.
	# Default implementation: return the alternative actions (and their children).
	def children()
		descendents = sequence.map() do |(aPattern, aChild)|
			indirectChildren = aChild.children
			
			( indirectChildren.empty? ? aChild : indirectChildren.unshift(aChild) )
		end

		return descendents.flatten()
	end

	# Strategy method. Apply the action(s) to the Lexer.
	def apply_to(aLexer)
		sequence.each do |(aPattern, anAction)|
			match_result = aLexer.scan(aPattern)	# Approximate match
			if match_result
				anAction.apply_to(aLexer)
			else
				aLexer.unknown_token()
			end
		end
		
		return nil	# Do we need a return value?
	end
	
private
	# Return the given pattern after its validation
	# A LexerSetupError exception is raised if the argument does not meet the validation.
	def validated_pattern(aPattern)
		raise LexerSetupError, "Pattern argument must be a String or a Regexp." unless [Regexp, String].include? aPattern.class()
	
		return aPattern
	end
	
	# Return the given pattern after its validation
	# An TypeError exception is raised if the argument does not meet the validation.	
	def validated_action(anAction)
		raise TypeError, "#{anAction} is not a LexerAction" unless anAction.kind_of?(LexerAction)
		
		return anAction
	end
end # class

end # module
# End of file