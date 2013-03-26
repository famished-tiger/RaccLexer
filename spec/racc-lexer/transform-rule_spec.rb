# encoding: utf-8 -- You should see a paragraph character: §
# File: token-queue_spec.rb

require_relative '../rspec_helper'
require_relative '../../lib/racc-lexer/transform-rule' # Load the class under testing


# Reopen the module, in order to get rid of fully qualified names
module RaccLexer	# This module is used as a namespace

describe TransformRule do
  # Variable that holds a Hash with pairs like:
  # keyword => token type symbol
  let(:sample_keywords) do 
    {
      'if' => :T_IF,
      'else' => :T_ELSE,
      'elsif' => :T_ELSIF,
      'end' => :T_END
    }
  end
  
  let(:sample_token_type) { :T_IDENTIFIER }
  
  let(:sample_transformation) do
    # Specialise identifier token type to a keyword type if necessary
    Proc.new do |a_token| 
      if sample_keywords.has_key? a_token.value
        [sample_keywords[a_token.value], a_token]
      else
        [:T_IDENTIFIER, a_token]
      end
    end
  end

  # Rule for creating a default instance called 'subject'
  subject { TransformRule.new(sample_token_type, sample_transformation) }  
  
  context "Creation & initialisation" do
    it 'should be created with a token type and a transformation arguments' do
      # Valid case
			lambda { TransformRule.new(sample_token_type, sample_transformation) }.should_not raise_error
      
      # Invalid case: wrong token type
      error_message = "A token type can only be a Symbol or a character"
      lambda { TransformRule.new(12345, sample_transformation) }.should raise_error(LexerSetupError, error_message)
      
      # Invalid case: wrong transformation object
      error_message = "A transformation should respond to the call message"
      lambda { TransformRule.new(sample_token_type, 12345) }.should raise_error(LexerSetupError, error_message)      
    end
    
  
    it 'should know the token type it applies to' do
      subject.token_type.should == sample_token_type
    end
    
    it 'should know its transformation' do
      subject.transformation.should == sample_transformation
    end

    context "Provided services" do
      it "should apply a transformation to a given token" do
        token1 = Token.new('if', 'if', nil) # This token represents a keyword
        (resulting_type, token) = subject.apply_to(token1)
        resulting_type.should be == :T_IF
        token.should be == token1
        
        token2 = Token.new('foobar', 'foobar', nil) # # This token is an identifier
        (resulting_type, token) = subject.apply_to(token2)
        resulting_type.should be == :T_IDENTIFIER
        token.should be == token2        
      end
      
      it "should complain when asked to apply itself to a non-Token object" do
        error_message = "Internal error: only RaccLexer::Token objects can be transformed. Found a String instead."
        lambda { subject.apply_to("foobar") }.should raise_error(InternalLexerError, error_message) 
      end
    end
  
  end # context
  
end # describe

end # module

# End of file