# File: lexer-rule_spec.rb

require 'pp'
require_relative '../rspec_helper'
require_relative '../../lib/racc-lexer/lexer-rule'  # The class under test
require_relative '../../lib/racc-lexer/event-handler'


# Reopen the module, in order to get rid of fully qualified names
module RaccLexer	# This module is used as a namespace

# These examples should apply to both StandardRule and LookaheadRule objects.
[RaccLexer::StandardRule, RaccLexer::LookaheadRule].each do |ruleClass|
	describe ruleClass do

		context "Creation & initialisation" do
			it 'should be created with a rule name' do
				# Error case: created without any argument
				lambda { ruleClass.new }.should raise_error(ArgumentError, 'wrong number of arguments (0 for 1)')
				
				# Valid case: create with a rule name
				lambda { ruleClass.new(:some_rule) }.should_not raise_error
			end
			
			it 'should know its name' do
				sample_name = :some_rule
				rule = ruleClass.new(:some_rule)
				rule.name.should == sample_name
			end
			
			it 'should have a default action initialized' do
				rule = ruleClass.new(:some_rule)
				default_action = rule.default_action
				default_action.should be_kind_of(SendMessageAction)
				default_action.message.should == :unknown_token
			end
			
			it 'should have the handlers attribute empty' do
				rule = StandardRule.new(:some_rule)
				rule.handlers.should be_empty
			end
			
		end # context
		
		context "Provided services" do
			it 'should add an event handler when requested' do
				rule = ruleClass.new(:some_rule)

				# Adding valid handlers...
				rule.add_handler(EventHandler.new(':', EnqueueToken.new(:NON_CAPTURING_GROUP)))
				rule.add_handler(EventHandler.new('>', EnqueueToken.new(:ATOMIC_GROUP)))
				rule.add_handler(EventHandler.new('=', EnqueueToken.new(:LOOKAHEAD_POS)))
				rule.handlers.size == 3
				
				# Are they really added?...
				actuals = rule.handlers.map { |aHandler| aHandler.pattern }
				actuals.should == %w[: > =]
			end
			
			it 'should update the default handler when requested' do
				rule = ruleClass.new(:some_rule)
				
				sample_token_type = :SOME_TOKEN
				a_default_action = EnqueueToken.new(sample_token_type)
				rule.default_action = a_default_action
				rule.default_action.should == a_default_action
			end
			
			it 'should keep its child list up-to-date' do
				rule = ruleClass.new(:some_rule)
				
				# Check initial child list
				rule.all_actions.should == [ rule.default_action ]
				
				# Adding valid handlers...
				rule.add_handler(EventHandler.new(':', EnqueueToken.new(:NON_CAPTURING_GROUP)))
				rule.add_handler(EventHandler.new('>', EnqueueToken.new(:ATOMIC_GROUP)))
				rule.add_handler(EventHandler.new('=', EnqueueToken.new(:LOOKAHEAD_POS)))
				
				rule.all_actions.size == 4
				count = rule.all_actions.count { |act| act.kind_of?(EnqueueToken) }
				count.should == 3
			end
		end # context
	end # describe
end # each class

describe StandardRule do
		context "Creation & initialisation:" do
			it 'could be created with a rule name an a before action' do
				# Case 1: correct before action
				lambda {StandardRule.new(:some_rule, EnqueueToken.new(:SOME_TOKEN)) }.should_not raise_error
				
				# Case 2: before action is nil (correct)
				lambda {StandardRule.new(:some_rule, nil) }.should_not raise_error
				
				# Case 3: incorrect before action
				lambda {StandardRule.new(:some_rule, 'Something wrong') }.should raise_error(LexerSetupError, "Rule 'some_rule': invalid before action 'Something wrong'.")
			end
			
			it 'should know its before action' do
				# Case 1: with before action explicitly set
				action = EnqueueToken.new(:SOME_TOKEN)
				rule1 = StandardRule.new(:some_rule, action)
				rule1.before_action.should == action
				
				# Case 2: before action is explicitly set to nil
				rule2 = StandardRule.new(:some_rule, nil)
				rule2.before_action.should be_nil
				
				# Case 3: no before action explicitly provided
				rule3 = StandardRule.new(:some_rule)
				rule3.before_action.should be_nil			
			end
		end

	context "Provided services" do
		it 'should complain when a multi-character an event handler is being added' do
			rule = StandardRule.new(:some_rule)
			
			# Adding an invalid handler (more than one character)
			lambda { rule.add_handler(EventHandler.new('multichar_text', EnqueueToken.new(:INVALID))) }.should raise_error(StandardError)
		end
		
		it 'should apply itself to a given Lexer' do
			rule = StandardRule.new(:some_rule)
			
			handler_one = EventHandler.new(':', EnqueueToken.new(:NON_CAPTURING_GROUP))
			handler_two = EventHandler.new(':', EnqueueToken.new(:ATOMIC_GROUP))
			handler_three = EventHandler.new('=', EnqueueToken.new(:LOOKAHEAD_POS))
			handler_four = EventHandler.new('!', EnqueueToken.new(:LOOKAHEAD_NEG))
			[handler_one, handler_two, handler_three, handler_four].each { |aHandler| rule.add_handler(aHandler) }
			
			# Create a first mock Lexer
			fake = mock('first')
			current_char = '='
			fake.should_receive(:next_char).and_return(current_char)
			expectation = [:LOOKAHEAD_POS, current_char]
			fake.should_receive(:enqueue_token).with(:LOOKAHEAD_POS).and_return(expectation)
			
			# Case 1: applying the rule with a matching event handler
			actual = rule.apply_to(fake)
			actual.should == expectation
			
			# Create a second mock Lexer
			dummy = mock('second')
			current_char = '~'
			dummy.should_receive(:next_char).and_return(current_char)
			prompt = 'default handler invoked!'
			dummy.should_receive(:unknown_token).and_return(prompt)
			
			# Case 2: applying the rule with no matching event handler.
			actual = rule.apply_to(dummy)
			actual.should == prompt			
		end
		
		it 'should apply the before action when specified' do
			before = EnqueueToken.new(:XGROUP)
			rule = StandardRule.new(:some_rule, before)
			
			handler_one = EventHandler.new(':', EnqueueToken.new(:NON_CAPTURING_GROUP))
			handler_two = EventHandler.new(':', EnqueueToken.new(:ATOMIC_GROUP))
			handler_three = EventHandler.new('=', EnqueueToken.new(:LOOKAHEAD_POS))
			[handler_one, handler_two, handler_three].each { |aHandler| rule.add_handler(aHandler) }
			
			# Create a mock Lexer
			fake = mock('fake-Lexer')
			current_char = '='
			fake.should_receive(:next_char).and_return(current_char)
			expectation = [
				[:XGROUP, '(?'],
				[:LOOKAHEAD_POS, current_char]
			]
			fake.should_receive(:enqueue_token).with(:XGROUP).and_return(expectation.first)	# Side-effect of before action
			fake.should_receive(:enqueue_token).with(:LOOKAHEAD_POS).and_return(expectation.last)
			fake.should_receive(:queue).and_return(expectation)
			
			# Case 1: applying the rule with a matching event handler
			rule.apply_to(fake)
			fake.queue.should == expectation	
		end		
	end # context	

end # describe


describe LookaheadRule do

	context "Provided services" do
		
		it 'should apply itself to a given Lexer' do
			rule = LookaheadRule.new(:some_rule)
			
			handler_one = EventHandler.new(/\d+>/, EnqueueToken.new(:NUM_BACKREF))
			handler_two = EventHandler.new(/-\d+>/, EnqueueToken.new(:NUM_REL_BACKREF))
			handler_three = EventHandler.new(/\w+>/, EnqueueToken.new(:NAME_BACKREF))
			handler_four = EventHandler.new(/\w+[-+]\d+>/, EnqueueToken.new(:NUM_LEVELLED_BACKREF))
			[handler_one, handler_two, handler_three, handler_four].each { |aHandler| rule.add_handler(aHandler) }
			
			# Create a first mock Lexer
			fake = mock('first')
			future_text = 'group>'
			fake.stub(:scan) do |aPattern|
				if future_text =~ aPattern
					future_text
				else
					nil
				end
			end
			expectation = [:NAME_BACKREF, future_text]
			fake.should_receive(:enqueue_token).with(:NAME_BACKREF).and_return(expectation)
			
			# Case 1: applying the rule with a matching event handler
			actual = rule.apply_to(fake)
			actual.should == expectation
			
			# Create a second mock Lexer
			dummy = mock('second')
			wrong_text = '?#%*wrong'
			dummy.stub(:scan).with(instance_of(Regexp)).and_return(nil)
			prompt = 'default handler invoked!'
			dummy.should_receive(:unknown_token).and_return(prompt)
			
			# Case 2: applying the rule with no matching event handler.
			actual = rule.apply_to(dummy)
			actual.should == prompt
			
		end
	end # context	

end # describe

end # module
# End of file