# encoding: utf-8 -- You should see a paragraph character: §
# File: token-queue_spec.rb

require_relative '../rspec_helper'
require_relative '../../lib/racc-lexer/token-queue' # Load the class under testing


# Reopen the module, in order to get rid of fully qualified names
module RaccLexer	# This module is used as a namespace

describe TokenQueue do
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
        [sample_token_type, a_token]
      end
    end
  end
  
  # A transform rule that returns from time to time nil.
  # It returns the couple [:T_IDENTIFIER, a_token] when the number of characters is even.
   # It returns nil when the number of characters is odd.
  let(:sample_filter) do
    # Specialise identifier token type to a keyword type if necessary
    Proc.new do |a_token| 
      if a_token.value.length.even?
        [sample_token_type, a_token]
      else
        nil # Return nil when value has an odd length
      end
    end
  end

  let(:sample_transform_rule) { TransformRule.new(sample_token_type, sample_transformation) } 


  context "Creation & initialisation" do

    it 'could be created without argument' do
			lambda { TokenQueue.new }.should_not raise_error
    end
    
    it 'could be created with an array of transform rules' do
      lambda { TokenQueue.new([sample_transform_rule]) }.should_not raise_error
    end

    it 'should be empty' do
      subject.should be_empty
    end
    
    it 'should know its transform rules (if any)' do
      # Case: no transform rule
      subject.rules.should be_empty
      
      # Case: one transform rule
       instance = TokenQueue.new([sample_transform_rule])
       instance.should have(1).rules
       instance.rules.keys.last.should == sample_transform_rule.token_type
    end

	end # context

  context "Enqueuing tokens" do
    it "should enqueue a couple" do
      # Case: no transform rule for token
      couple1 = [:T_IDENTIFIER, Token.new('foobar', 'foobar', nil)] 
      lambda { subject.enqueue(couple1) }.should_not raise_error
      subject.should have(1).tokens
      subject.tokens.last.should == couple1
    end
    
    
    it "should complain when input argument isn't a couple" do
      error_message = "Internal error: a token queue element must be an Array."
      lambda { subject.enqueue("Wrong argument type") }.should raise_error(InternalLexerError, error_message)
    end


    it "should complain when input argument is an Array of size != 2" do
      error_message = "Internal error: token queue accepts Array of size 2 only."
      lambda { subject.enqueue([]) }.should raise_error(InternalLexerError, error_message)
      lambda { subject.enqueue([:ONE_ELEMENT]) }.should raise_error(InternalLexerError, error_message)
      lambda { subject.enqueue([:THREE_ELEMENTS, 'a', 'b']) }.should raise_error(InternalLexerError, error_message)          
    end
    
    it "should complain when input argument does not have a char or a Symbol as its first element" do
      error_message = "Internal error: token type must be a String or Symbol, found a Fixnum instead."
      lambda { subject.enqueue([1234, 'first element is wrong']) }.should raise_error(InternalLexerError, error_message)       
    end
    
    it "should trigger a transformation rule when a rule applies to the element to enqueue" do
      instance = TokenQueue.new([sample_transform_rule])
      couple1 = [:T_IDENTIFIER, Token.new('foobar', 'foobar', nil)]
      instance.enqueue(couple1)
      instance.should have(1).tokens
      instance.tokens.first.should == couple1 # No transformation because foobar isn't a keyword...
      
      # Check a transformation
      couple2 = [:T_IDENTIFIER, Token.new('if', 'if', nil)]
      instance.enqueue(couple2)
      instance.should have(2).tokens
      transformed = instance.tokens.first #  Transformation because 'if' is a keyword...
      transformed.first.should == :T_IF
      transformed[1].should == couple2[1]
      
      # Check a filtering
      couple3 = [:T_IDENTIFIER, Token.new('odd', 'odd', nil)]      
      instance2 =  TokenQueue.new([TransformRule.new(sample_token_type, sample_filter)])
      instance2.enqueue(couple3)
      instance2.should have(0).tokens # 'odd' should not be enqueue (because it contains an odd number of characters)
      
      couple4 = [:T_IDENTIFIER, Token.new('even', 'even', nil)]      
      instance2.enqueue(couple4)
      instance2.should have(1).tokens
      instance2.tokens.first.should == couple4
    end
  end # context
  
  context "Dequeuing tokens" do
    it "should complain when the queue is empty" do
      error_message = "Internal error: cannot dequeue: the token queue is already empty."
      lambda { subject.dequeue }.should raise_error(InternalLexerError, error_message)
    end  
  end # context

end # describe

end # module

# End of file