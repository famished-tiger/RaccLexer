# encoding: utf-8 -- You should see a paragraph character: §
# File: event-handler_spec.rb

require 'pp'

require_relative '../rspec_helper'
require_relative '../../lib/racc-lexer/lexer-action'
require_relative '../../lib/racc-lexer/event-handler' # Load the class under testing

# Reopen the module, in order to get rid of fully qualified names
module RaccLexer	# This module is used as a namespace

describe EventHandler do
	context "Creation & initialisation" do
		it 'should be created with a pattern and an action' do
			# Error case: created without any argument
			lambda { EventHandler.new }.should raise_error(ArgumentError, 'wrong number of arguments (0 for 2)')

			# Valid case
			lambda { EventHandler.new('(', EnqueueToken.new('(')) }.should_not raise_error
		end
		
		it 'should know its pattern' do
			sample_char = '('
			handler = EventHandler.new(sample_char, EnqueueToken.new('(')) 
			handler.pattern.should == sample_char
		end
		
		it 'should know its action' do
			sample_action = EnqueueToken.new('(')
			handler = EventHandler.new(/[abc]/, sample_action) 
			handler.action.should == sample_action
			handler.all_actions.should == [ sample_action ]
		end
	end # context	
	
	context "Provided services" do
		it 'should indicate whether a given text matches its pattern' do
			sample_action = EnqueueToken.new('(')
			handler = EventHandler.new(/[abc]/, sample_action)
			handler.should_not be_matching('d')
			%w[a b c].each { |aChar| handler.should be_matching(aChar) }
		end
		
		it 'should apply its action to the given Lexer' do
			sample_action = EnqueueToken.new(:TOKEN_TYPE)
			handler = EventHandler.new(/a/, sample_action)

			fake = mock('Lexer')
			simulated_lexeme = 'spiff'
			expectation = [:TOKEN_TYPE, simulated_lexeme]
			fake.should_receive(:enqueue_token).with(:TOKEN_TYPE).and_return(expectation)
			#fake.should_receive(:tokenizing_state=).with(:Recognized)
			
			handler.apply_to(fake).should == expectation
		end
	end # context

end # describe


end # module
# End of file