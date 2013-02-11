# encoding: utf-8 -- You should see a paragraph character: §
# File: lexeme-position_spec.rb

require_relative '../rspec_helper'
require_relative '../../lib/racc-lexer/token' # Load the class under testing

# Re-open the module, in order to get rid of fully qualified names
module RaccLexer	# This module is used as a namespace

describe Token do
  # Constant that holds a sample token position
  SamplePosition = LexemePosition.new(10, 1, 5)


  # Rule for creating a default instance named 'subject'
  subject do
    Token.new(1234, '1234', SamplePosition)
  end


  context "Creation & initialization" do
    it 'should be created with three arguments' do
      lambda {  Token.new(1234, '1234', SamplePosition) }.should_not raise_error
    end

    it 'should know its lexeme' do
      subject.lexeme.should == '1234'
    end

    it 'should know its value' do
      subject.value.should == 1234
    end

    it 'should know its position' do
      subject.position.should == SamplePosition
    end
  end # context


  context "Comparing with another token" do
    it 'should compare positively with itself' do
      subject.should == subject
    end
    
    it 'should compare with another Token' do
      subject.should == Token.new(1234, '1234', LexemePosition.new(10, 1, 5))
      subject.should_not == Token.new('1234', '1234', SamplePosition)
      subject.should_not == Token.new(1234, '5678', SamplePosition) 
      subject.should_not == Token.new(1234, '5678', LexemePosition.new(10, 1, 6))      
    end
    
    it 'should compare with a text value' do
      instance = Token.new('name', 'NAME', SamplePosition)
      instance.should == 'name'
    end
    
    it 'should compare with a couple' do
      # A couple like [value, a position array]
      subject.should == [1234, [10, 1, 5]]
      subject.should == [1234, [10, 1]]
      subject.should == [1234, [10]]

      subject.should_not == [4567, [10]]
      subject.should_not == [1234, [11]]      
    end
  end # context

end # describe

end # module

# End of file