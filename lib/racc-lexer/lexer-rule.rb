# File: lexer-rule.rb

require_relative '../abstract-method'
require_relative 'event-handler'
require_relative 'lexer-action'
require_relative 'lexer-exceptions'

module RaccLexer	# This module is used as a namespace


# A lexer rule tells a Lexer what to do when an input character has been read.
# A lexer rule has:
#- a name, so that another rule can reference this one.
# It may also have:
#- one "before action" that operate on currently scanned lexeme (e.g. build a token from it, clear the lexeme)
#- one or more event handlers. One event handler tells what to do when a specific character or
# a text that matches a regexp was found in the input stream.
#- one default action. It is launched when the input text doesn't match any handler event.
class LexerRule
	include AbstractMethod
	
	# Symbolic name of the tokenizing rule. Must be unique amongst all rules known to a Lexer.
	attr_reader(:name)
	
	# The action to perform when the rule is invoked/applied and before any event handler is used.
	# Before actions operate usually on the currently scanned lexeme(e.g. build a token from it, clear the lexeme).
	# It should have a side effect on the Lexer itself.
	attr_reader(:before_action)
	
	# An Array that specifies how the Lexer should react given a character at current scanning position.
	# The Array consists of couples of event handlers.
	#[character, action] or [regexp, action]
	# Where: 
	# action is itself an LexerAction:
	# [:token, aTokenSymbol]
	# [:rule, aRuleSymbol]
	# [:expectation, anExpectationHash] where: anExpectionHash contains pairs like {regexp => aTokenSymbol or aTokenSelector}
	attr_reader(:handlers)
	
	# The recognition action to launch when no handler matches the input
	attr(:default_action)
	
	
	# Constructor.
	# [aName]	A Symbolic name for the rule.
	def initialize(aName, aBeforeAction = nil)
		@name = validated_name(aName)
		@handlers = []
		@before_action = validated_action(aBeforeAction)		
		@default_action = SendMessageAction.new(:unknown_token)
	end
	
public
	# Add an event handler
	def add_handler(aHandler)
		handlers << validated_handler(aHandler)
	end
	
	# Abstract method. Apply the rule to the given Lexer.
	# It should return a token in the format requested by the parser.
	# [aLexer]	A Lexer that should respond to the messages sent
	#  by any action...
	def apply_to(aLexer) abstract_method
	end
	
	# Set the default action for the rule.
	def default_action=(anAction)
		@default_action = anAction
	end
	
	# Return all actions that might be executed with this rule
	def all_actions()
		handler_actions =  handlers.map {|aHandler| aHandler.all_actions }
		almost_complete = handler_actions + default_action.children
		if before_action.nil?
			children_raw = almost_complete << default_action
		else
			children_raw = (before_action.children + [before_action] + almost_complete) << default_action
		end
		return children_raw.flatten
	end
	
protected
	# return the passed name after validation.
	# Rule: name cannot be empty
	def validated_name(aName)
		raise LexerRuleError, "Rule cannot have an empty name" if aName.empty?
		return aName
	end

	# Abstract method. Purpose: return the passed event handler after validation.
	# An exception should be raised when any validation rule is not met.
	def validated_handler(aHandler) abstract_method
	end
	
	# Return the validated before action.
	# An exception is raised when the action is not a Lexer action nor nil.	
	def validated_action(aBeforeAction)
		raise LexerRuleError, "Rule '#{name}': invalid before action '#{aBeforeAction}'." unless aBeforeAction.nil? || aBeforeAction.kind_of?(LexerAction)
		
		return aBeforeAction
	end	


	# Apply the action to the Lexer.
	# Result of the action is returned.
	# [anAction] A LexerAction. If nil, then the default action is applied.
	def apply_action(anAction, theLexer)
		action = anAction.nil? ? default_action : anAction
		begin
			result = action.apply_to(theLexer)
		rescue LexerSetupError => exc
			raise exc	# Re-raise the exception
		end
		return result
	end
	
end # class

# A specialization of a Lexer rule. At the start of an invokation,
# the rule eats the next char from the Lexer then tries the first event handler 
# that accepts the read character.
# Each event handler should match a single character.
class StandardRule < LexerRule
	# Constructor.
	# [aName]	A Symbolic name for the rule.
	# [aBeforeAction] A Lexer action that will be performed when the rule is applied and any before event handling.
	def initialize(aName, aBeforeAction = nil)
		super(aName, aBeforeAction)
	end
	
public
	# Re-defined method. Apply the rule to the given Lexer.
	# First a character is read(consumed) from the Lexer.
	# Second, the action associated with the first handle that accepts the scanned character is executed.
	# It should return a token in the format requested by the parser.
	# [aLexer]	A Lexer that should respond to the messages sent
	#  by any action...
	def apply_to(aLexer)
		apply_action(before_action, aLexer) unless before_action.nil?
		
		current_char = aLexer.next_char()
		
		found_action = nil
		handlers.each do |aHandler|
			if aHandler.matching? current_char
				found_action = aHandler.action
				break
			end
		end
		
		return apply_action(found_action, aLexer)
	end		
	
protected	
	# Overriding method. Purpose: return the passed event handler after validation.
	# An exception is raised when the pattern consists of more than one character.
	def validated_handler(aHandler)
		if aHandler.pattern.kind_of?(String)
			raise LexerRuleError, "Only single character can be handled in standard Lexer rule" unless aHandler.pattern.length == 1			
		end
	
		return aHandler
	end
end # class


# A specialization of a Lexer rule.
# the rule tries to find the first event handler that matches the text AFTER the current position.
# The Lexer scanning position is not updated until a match is found.
# When a match is found, then 
# that accepts the read character.
# Each event handler should match a single character.
class LookaheadRule < LexerRule
	# Constructor.
	# [aName]	A Symbolic name for the rule.
	# [aBeforeAction] A Lexer action that will be performed when the rule is applied and any before event handling.
	def initialize(aName, aBeforeAction = nil)
		super(aName, aBeforeAction)
	end
	
public
	# Re-defined method. Apply the rule to the given Lexer.
	# It tries to match the input text to scan to one of the pattern. Then the associated action is executed.
	# It should return a token in the format requested by the parser.
	# [aLexer]	A Lexer that should respond to the messages sent
	#  by any action...
	def apply_to(aLexer)
		apply_action(before_action, aLexer) unless before_action.nil?
		
		found_action = nil
		handlers.each do |aHandler|
			if aLexer.scan(aHandler.pattern)
				found_action = aHandler.action
				break
			end
		end
		
		return apply_action(found_action, aLexer)
	end	
	
protected	
	# Overriding method. Purpose: return the passed event handler after validation.
	def validated_handler(aHandler)
	
		return aHandler
	end
end # class


end # module
# End of file