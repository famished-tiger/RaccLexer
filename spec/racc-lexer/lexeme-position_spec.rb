# encoding: utf-8 -- You should see a paragraph character: §
# File: lexeme-position_spec.rb

require_relative '../rspec_helper'
require_relative '../../lib/racc-lexer/lexeme-position' # Load the class under testing

# Re-open the module, in order to get rid of fully qualified names
module RaccLexer	# This module is used as a namespace

describe LexemePosition do

  # Rule for creating a default instance named 'subject'
  subject { LexemePosition.new(10, 1, 5) }


  context "Creation & initialization" do
    it 'should be created with three integer arguments' do
      lambda { LexemePosition.new(10, 1, 5) }.should_not raise_error
    end

    it 'should complain when the line pos takes an unrealistic value' do
      error_message = "Internal error: invalid value for position relative to start of in line"
       lambda { LexemePosition.new(10, 1, 15) }.should raise_error(InternalLexerError, error_message)
    end

    it 'should know its offset' do
      subject.offset.should == 10
    end

    it 'should know its line number' do
      subject.lineno.should == 1
    end

    it 'should know the position relative to start of line' do
      subject.line_pos.should == 5
    end
  end # context

  context "Comparing with another position" do
    it 'should compare positively with itself' do
      subject.should == subject
    end

    it 'should compare with another LexemePosition' do
      subject.should == LexemePosition.new(10, 1, 5)
      subject.should_not == LexemePosition.new(11, 1, 5)
      subject.should_not == LexemePosition.new(10, 2, 5)
      subject.should_not == LexemePosition.new(10, 1, 4)
    end

    it 'should complain when compared to an empty array' do
      error_message = "Internal error: empty array may not specify a token position"
       lambda { subject == [] }.should raise_error(InternalLexerError, error_message)
    end
    
    it 'should complain when compared to an array of non-Fixnum' do
      error_message = "Internal error: only integers allowed for token position"
       lambda { subject == %w[a b c] }.should raise_error(InternalLexerError, error_message)
    end
    
    it 'should compare to an offset value' do
      subject.should == 10
      subject.should_not == 11
      
      # By convention a single element array contains the offset value
      subject.should == [10]
      subject.should_not == [11]
    end

    it 'should compare to an array of size 2' do
      # By convention a two-elements array contains: offset value, line number
      subject.should == [10, 1]
      subject.should_not == [10, 2]
    end 
    
    it 'should compare to an array of size 3' do
      # By convention a three-elements array contains: offset value, line number, offset relative to start of last line
      subject.should == [10, 1, 5]
      subject.should_not == [10, 1, 4]
    end

    it 'should complain when compared to an array of size > 3' do
      error_message = "Internal error: wrong array size for specifying a token position"
      lambda { subject == [10, 1, 5, 0] }.should raise_error(InternalLexerError, error_message)    
    end
    
    it 'should answer negatively when compared to something else' do
      subject.should_not == 'some text'
    end
  end

end # describe

end # module

# End of file