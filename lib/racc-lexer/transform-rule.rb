# File: token-queue.rb

require_relative 'lexer-exceptions'
require_relative 'token'

module RaccLexer # This module is used as a namespace

# A transform rule specifies a transformation for a token of a given type.
# Transformation rules are activated when a token is being enqueued in a token queue.
class TransformRule
  # The token type for which this transform rule may apply.
  # A token type represents a terminal symbol in a RACC grammar.
  # It can be a single character or a Symbol object.
  attr(:token_type)

  # A block of code that takes a Token as an input argument and
  # results in a pair [token type, Token object] or nil.
  # In principle, can be any object that responds to the 'call' method (with one argument).
  attr(:transformation)

  # Constructor.
  # [aTokenType] See doc of 'token_type' attribute.
  # [aTransformation] See doc of 'transformation' attribute
  def initialize(aTokenType, aTransformation)
    @token_type = validated_token_type(aTokenType)
    @transformation = validated_transformation(aTransformation)
  end

public
  # Apply the transformation to the given token object.
  # [aToken] should be a Token object.
  # Precondition: caller checked that the token type associated of the passed token object
  # matches the token_type of the rule.
  # Return nil or a pair of the form [token type, Token object]
  def apply_to(aToken)
    raise InternalLexerError.new("only RaccLexer::Token objects can be transformed. Found a #{aToken.class} instead.", nil) unless aToken.kind_of?(Token)

    return transformation.call(aToken)
  end


private
  def validated_token_type(aTokenType)
    raise LexerSetupError.new("A token type can only be a Symbol or a character") unless [Symbol, String].include? aTokenType.class
    if aTokenType.kind_of?(String)
      raise LexerSetupError.new("Found a token type that is a String with size != 1") unless aTokenType.size != 1
    end

    return aTokenType
  end

  def validated_transformation(aTransformation)
    raise LexerSetupError.new("A transformation should respond to the call message") unless aTransformation.respond_to?(:call)

    return aTransformation
  end

end # class

end # module

# End of file