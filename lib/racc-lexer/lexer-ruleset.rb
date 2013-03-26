# File: lexer-ruleset.rb

require 'forwardable'	# To provide a Hash-like interface...
require_relative 'lexer-exceptions'

module RaccLexer # This module is used as a namespace

# A collection of Lexer rules.
# It is a thin wrapper around a Hash with pair of the kind: rule name => rule object
class LexerRuleset
	extend Forwardable	# So that some messages are forwarded to the embedded Hash object.
	def_delegators :@rules, :empty?, :size, :length, :[], :<<, :keys, :fetch
	
	# A Hash with pairs like: token_type Symbol or character => description
	# It specifies all the token types for the language
	attr_reader(:token_types)
	
	# A Hash with pairs like: rule name => rule object
	attr_reader(:rules)
	
	# Constructor. Begin with an empty rule set.
	def initialize()
		@rules = {}
		@token_type = nil
	end
	
public
	# Setter for the token type dictionary
	# [theTokenTypes] aHash with pairs like: token type => descriptive text
	# A token type is either a Symbol or a character
	def token_types=(theTokenTypes)
		raise LexerSetupError, "Token types can be specified only once." unless token_types.nil?
		@token_types = theTokenTypes
	end
	
	# Add a given rule to the rule set.
	# A LexerRuleError is raised if there is already a rule having the same name (unicity!).
	def add_rule(aLexerRule)
		raise LexerRuleError.new("The rule set has no token types defined", nil) if @token_types.nil?
		raise LexerRuleError.new("Two tokenizing rules may not have the same name #{aLexerRule.name}.", nil) if rules.has_key? aLexerRule.name
    
    validated_rule = validate_rule(aLexerRule)    
		rules[aLexerRule.name] = validated_rule
	end
	
	# Apply validation rules upon the set of lexer rules.
	# For instance, check that each subrule reference points to an existing rule.
	def validate()
		rules.values.each do |aRule|
			subrule_invokations = aRule.all_actions.select { |act| act.kind_of?(ApplySubrule) }
			subrule_invokations.each do |invokation| 
				raise LexerRuleError, "Reference to unknown subrule '#{invokation.rulename}' in rule '#{aRule.name}'." unless rules.has_key? invokation.rulename 
			end
		end
	end
	
	# Apply validation rules upon the given rule.
	# Rule name should be unique within a ruleset
	# recognized tokens must refer to a known token type.
	def validate_rule(aLexerRule)
		# Actions using a token type must refer to a known token types 
		actions_with_token = aLexerRule.all_actions.select { |anAction| anAction.kind_of?(EnqueueToken) }
		actions_with_token.each do |action|
			raise LexerRuleError.new("Rule '#{aLexerRule.name}' refers to unknown token type '#{action.token_type}'", nil) unless token_types.has_key?(action.token_type)
		end
		
		return aLexerRule
	end
	
	# List all the tokens in format compatible with Racc.
	# TODO: use erubis template
	def declare_tokens(anIO)
		# Retain only the symbol token types
		symbolic_ones = token_types.keys.select {|aTokenType| aTokenType.kind_of?(Symbol)}
		sorted_types = symbolic_ones.sort
		anIO.puts "# Declare the tokens (terminal symbols) registered in the lexer."
		anIO.puts "# Remark special characters are returned 'as is'"
		anIO.puts "token"
		sorted_types.each do |aTokenType|
			anIO.puts "\t#{aTokenType}    # #{token_types[aTokenType]}"
		end
	end

end # class

end # module

# End of file