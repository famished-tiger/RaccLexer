# encoding: utf-8  -- You should see a paragraph character: §
# File: lexer-rule-dsl.rb

require_relative 'lexer-rule'
require_relative 'lexer-ruleset'

module RaccLexer	# This module is used as a namespace


# Utility class that defines a DSL (Domain-specific language) to build LexerRules.
class LexerRuleDsl

	# An Array with all the known rules.
	attr_reader(:ruleset)

	# Constructor
	def initialize()
		@ruleset = LexerRuleset.new
	end
	
public
	# Convenience method. Build an instance & return the resulting set of rules after the block evaluation.
	# The returned set of rules is a Hash with pairs of the form: rule name => rule
	def self.ruleset(&aBlock)
		instance = self.new
		instance.instance_eval &aBlock
		
		return instance.ruleset
	end
	
	# Specify all the token types defined in the language.
	# [theTokenTypes] aHash with pairs like: token type => descriptive text
	# A token type is either a Symbol or a character
	def tokens(theTokenTypes)
		ruleset.token_types = theTokenTypes
	end 
	
	# Part of DSL.
	# Build a standard one-char Lexer rule with given name and actions specified in the block argument
	def rule(aName, aBeforeAction = nil, &aBlock)
		new_rule = StandardRule.new(aName, aBeforeAction)
		process_rule(new_rule, &aBlock)
	end
	
	# Part of DSL.
	# Build a lookahead Lexer rule with given name and actions specified in the block argument
	def lookahead_rule(aName, aBeforeAction = nil, &aBlock)
		new_rule = LookaheadRule.new(aName, aBeforeAction)
		process_rule(new_rule, &aBlock)
	end	
	
	# Part of DSL.
	# [aPair] a single-element Hash. The pair should be of the form:
	# a character => action; or
	# a regexp => action
	def on(aPair)
		raise StandardError, "on accepts a single mapping" unless aPair.size == 1
		handler = EventHandler.new(aPair.keys.first, aPair[aPair.keys.first])
		last_rule.add_handler(handler)
	end
	
	# Part of DSL.
	# Return a SendMessageAction.	
	def method(*args)
		return SendMessageAction.new(*args)
	end
	
	# Part of DSL.
	# Return a BuiltToken action.
	# [aTokenType]	A Symbol/character that represents a token type.
	# It must be one of the registered token types 	
	def recognize(aTokenType)
		return EnqueueToken.new(aTokenType)
	end

	# Part of DSL.
	# Purpose: allow a rule to refer to a child rule.
	def subrule(aRulename)
		return ApplySubrule.new(aRulename)
	end
	
	# Part of DSL.
	# Purpose: "Put" the lexeme back in the input.
	def putback()
		return UndoScan.new
	end
  
	# Part of DSL.
	# Purpose: Clear the lexeme string.
	def clear()
		return Clear.new
	end  
	
	# Part of DSL.
	# Purpose: Create a sequence of actions to execute.	
	def procedure(anActionList)
		return ActionSequence.new(anActionList)
	end
	
	# Part of DSL.
	# Purpose: Transform the token type of last enqueued token, provided it has a given 'before' token type	
	# Example: mutate '-' => :CHARLIT
	def mutate(aPair)
		return MutateToken.new(aPair.keys.first, aPair.values.first)
	end	
	
	
	# Part of DSL.
	# Purpose: build a sequence of patterns, each pattern is associated with an action.
	# [patternActionPairs] an Array with couples of the form: [ pattern, action ]
	def pattern_seq(patternActionCouples)
		return ConditionalActionSequence.new(patternActionCouples)
	end

	# Part of DSL.
	# Return a ChoiceOnLookahead action.
	# [aCouple]	an pattern token action couple
	def choice(aPattern, matchingAction, no_matching_action = nil)
		return ChoiceOnLookahead.new(aPattern, matchingAction, no_matching_action)
	end
	
	# Part of DSL.
	# Return a ChoiceOnLexeme action.
	# [aCouple]	an pattern token action couple
	def choice_lexeme(aPattern, matchingAction, no_matching_action = nil)
		return ChoiceOnLexeme.new(aPattern, matchingAction, no_matching_action)
	end
	
	# Part of DSL.
	# Induce a state change in the Lexer
	# Return a ChoiceOnLexeme action.
	# [aCouple]	an pattern token action couple
	def change_state(aMethodName, theDestinationState, aPostAction)
		return ChangeState.new(aMethodName, theDestinationState, aPostAction)
	end	

	# Part of DSL.
	# Specify the default action for the tokenizing rule.
	# [anAction]
	def otherwise(anAction)
		raise StandardError, "otherwise expects an Lexer action instead of #{anAction.class}" unless anAction.kind_of?(LexerAction)
		last_rule.default_action = anAction
	end

	
private
	def last_rule()
		last_key = ruleset.keys.last	# Assumption: keys are ordered by insertion time 
		return ruleset[last_key]
	end
	
	# [aRule] a LexerRule
	def process_rule(aRule, &aBlock)
		@ruleset.add_rule(aRule)
		instance_eval(&aBlock)	# Give the chance to complete the rule
		
		# Now validate it.
		@ruleset.validate_rule(aRule)	
	end
end # class

end # module

# End of file