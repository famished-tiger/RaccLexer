# File: token-queue.rb

require_relative 'lexer-exceptions'
require_relative 'transform-rule'

module RaccLexer # This module is used as a namespace


# A FIFO (First In-First Out) queue that contains
# the tokens found in the input text stream by the lexer.
# The queue elements should be in the format compatible with a RACC-generated parser:
# An array of two elements with the:
# -first element being either the token type (a single character or
# a Symbol that appears in the tokens section of the RACC grammar file).
# -second element being a RaccLexer::Token object.
# A TokenQueue does a little more than a simple queue: when an element is being enqueued
# it will activate a transformation rule matching the token type (if present).
# A transformation rule can be used to modify, normalise or even dismiss the input element.
class TokenQueue
  # The link to the lower-level queue of tokens
  attr_reader(:tokens)
  
  # A Hash with with pairs of the kind:
  # token type => TransformRule
  attr_reader(:rules)
  
  
  # Constructor.
  # [transformRules] An Array of TransformRule objects
  def initialize(transformRules = [])
    @tokens = []
    @rules = {}
    
    transformRules.each do |a_rule|
      raise TypeError unless a_rule.kind_of?(TransformRule)
      raise LexerRuleError.new("More than one transform rule for token type '#{ a_rule.token_type}'", nil) if rules.has_key? a_rule.token_type
     
      @rules[a_rule.token_type] = a_rule # Add the rule...
    end
  end
  
public
  # Return true iff there is no element in the queue.
  def empty?
    return tokens.empty?
  end

  # Given the token pair passed as argument, enqueue it after subjecting it to a transformation
  # rule (if any).
  # [aTokenCouple] a couple of the form:
  # [token type, a Token object]
  def enqueue(aTokenCouple)
    valid_couple = validated_couple(aTokenCouple)
    (token_type, token_object) = valid_couple
    
    if rules.has_key?(token_type)
      transformed = rules[token_type].apply_to(token_object)
      return if transformed.nil?  # A nil means: ignore the token (= don't enqueue it)
      
      # Enqueue the resulting pair after its validation.
      tokens.unshift(validated_couple(transformed))
    else
      tokens.unshift(valid_couple)
    end
  end
  
  # Take an element from the queue.
  # An exception is raised if the queue is empty.
  def dequeue()
    element = tokens.pop()
    raise InternalLexerError.new("Cannot dequeue: token queue is already empty.", nil) if element.nil?
    
    return element
  end
  
private
  # Validation method. Checks that the argument is:
  # -An array with 2 elements
  # -The first element is a String or a Symbol
  # When valid, returns the input argument. Otherwise an exception is raised.
  def validated_couple(aTokenCouple)
    raise InternalLexerError.new("A token queue element must be an Array.", nil) unless aTokenCouple.kind_of?(Array)
    raise InternalLexerError.new("Token queue accepts Array of size 2 only.", nil) unless aTokenCouple.size == 2
    (token_type, token_object) = aTokenCouple
    raise InternalLexerError.new("Token type must be a String or Symbol, found a #{token_type.class} instead.", nil) unless token_type.kind_of?(String) || token_type.kind_of?(Symbol)
    
    return aTokenCouple
  end
end # class

end # module

# End of file