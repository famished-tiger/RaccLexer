# encoding: utf-8 -- You should see a paragraph character: §
# File: LexerAction_spec.rb

require_relative '../rspec_helper'
require_relative '../../lib/racc-lexer/lexer-action' # Load the class under testing


# Reopen the module, in order to get rid of fully qualified names
module RaccLexer	# This module is used as a namespace

describe SendMessageAction do
  # Special variables...
  let(:sample_message) { :some_message }
	let(:arguments) { [1, 2, 'three', :four] }


	context "Creation & initialisation" do

    # Rule for creating a default instance called 'subject'
    subject { SendMessageAction.new(sample_message) }

		it 'should be created with a message name and 0..* arguments' do
			# Error case: created without any argument
			lambda { SendMessageAction.new }.should raise_error(ArgumentError, 'wrong number of arguments (0 for 1)')

			# Error case: first argument of wrong type -should be a symbol-
			invalid_argument = [1, 2, 3]
			lambda { SendMessageAction.new invalid_argument }.should raise_error(TypeError, "[#{invalid_argument.join(', ')}] is not a symbol")

			# Valid case: created with just a message name
			lambda { SendMessageAction.new(:some_message) }.should_not raise_error

			# Valid case: created with a message name and arguments
			lambda { SendMessageAction.new(:some_message, arguments) }.should_not raise_error
		end

		it 'should know its message name and its arguments' do
			# Case: created with just a message name
			subject.message.should == :some_message
			subject.args.should be_empty

			# Case: created with a message name and arguments
			instance = SendMessageAction.new(sample_message, *arguments)
			instance.message.should == :some_message
			instance.args.should == arguments
		end

		it 'should know its child (if any)' do
      subject.children.should be_empty
		end

	end # context

	context "Provided services" do
		it 'should apply its action to the given Lexer' do
			expectation = 'abc'

			# Case: create an appropriate mockup Lexer that responds to the specified message
			fake = mock('fake')

			# Check the incoming message and reply to it
			fake.should_receive(sample_message).with(*arguments).and_return(expectation)

			# Create action object
			action = SendMessageAction.new(sample_message, *arguments)
			action.apply_to(fake).should == expectation

			# Case: use a -mock- lexer that doesn't know the received message
			dummy = mock('dummy')
			lambda { action.apply_to(dummy) }.should raise_error
		end
	end # context

end # describe

describe EnqueueToken do
	context "Creation & initialisation" do
		it 'should be created with a token type' do
			# Error case: created without any argument
			lambda { EnqueueToken.new }.should raise_error(ArgumentError, 'wrong number of arguments (0 for 1)')

			# Error case: argument of wrong type -should be a symbol or a string-
			invalid_argument = [1, 2, 3]
			lambda { EnqueueToken.new invalid_argument }.should raise_error(TypeError, "[#{invalid_argument.join(', ')}] is not a symbol nor a string")

			# Case: argument is a symbol
			lambda { EnqueueToken.new :SOME_TOKEN_TYPE }.should_not raise_error

			# Case: argument is a character
			lambda { EnqueueToken.new '[' }.should_not raise_error
		end
	end # context

	context "Provided services" do
		it 'should apply its action to the given Lexer' do
			# Test sample input data
			token_type_1 = :SOME_TTYPE
			current_lexeme = 'some-text'

			# Case: create an appropriate mockup Lexer that responds to the specified message
			fake = mock('fake')

			# Check the incoming message and reply to it
			fake.should_receive(:enqueue_token).with(token_type_1).and_return([token_type_1, current_lexeme])

			# Create action object
			action = EnqueueToken.new(token_type_1)
			action.apply_to(fake).should == [token_type_1, current_lexeme]

			# Case: create a mockup simulating a Lexer at the end of stream
			done = mock('at_end')
			eos_marker = [false, '$']	# This is the final token expected by any RACC-generated parser
			done.should_receive(:enqueue_token).with(:EOS).and_return(eos_marker)

			action = EnqueueToken.new(:EOS)
			action.apply_to(done).should == eos_marker
		end

		it 'should know its child (if any)' do
			instance = EnqueueToken.new(:SOME_TOKEN)
			instance.children.should be_empty
		end
	end # context

end # describe

describe ApplySubrule do
	context "Creation & initialisation" do
		it 'should be created with a rule name' do
			# Error case: created without any argument
			lambda { ApplySubrule.new }.should raise_error(ArgumentError, 'wrong number of arguments (0 for 1)')

			# Error case: first argument of wrong type -should be a symbol-
			invalid_argument = [1, 2, 3]
			lambda { ApplySubrule.new invalid_argument }.should raise_error(TypeError, "[#{invalid_argument.join(', ')}] is not a symbol")

			# Valid case: created with a rule name
			lambda { ApplySubrule.new(:some_rule) }.should_not raise_error
		end

		it 'should know the sub-rule name' do
			subrule_name = :some_rule

			instance = ApplySubrule.new(subrule_name)
			instance.rulename.should == subrule_name
		end

	end # context

	context "Provided services" do
    let(:subrulename) { :SOME_RULE }
    subject { ApplySubrule.new(subrulename) }
    
		it 'should apply its action to the given Lexer' do
			# Test sample input data
			sample_message = 'Sub-rule invoked!'

			# Create a subrule mock
			fake_subrule = mock('subrule')

			# Create an appropriate mockup Lexer that behaves as required
			fake_lexer = mock('lexer')

			# Return the rule set when requested
			fake_lexer.should_receive(:find_rule).with(subrulename).and_return(fake_subrule)

			# Add behaviour to the subrule
			fake_subrule.should_receive(:apply_to).and_return(sample_message)

			# Create the action object and apply it to (mock) Lexer
			subject.apply_to(fake_lexer).should == sample_message
		end

		it 'should know its child (if any)' do
			subject.children.should be_empty
		end

	end # context

end # describe


describe UndoScan do
	context "Creation & initialisation" do
		it 'should be created without any argument' do
			# Valid case: created without any argument
			lambda { described_class.new }.should_not raise_error
		end
	end # context

	context "Provided services" do
		it 'should apply its action to the given Lexer' do
			# Test sample input data
			token_type_1 = :SOME_TTYPE
			current_lexeme = 'some-text'

			# Case: create an appropriate mockup Lexer that responds to the specified message
			fake = mock('fake')

			# The Lexer is expected receive the unscan message
			fake.should_receive(:unscan)

			# Create action object
			subject.apply_to(fake)
		end

		it 'should know its child (if any)' do
			subject.children.should be_empty
		end
	end # context

end # describe


describe Clear do
	context "Creation & initialisation" do
		it 'should be created without argument' do
			# Valid case: created without any argument
			lambda { described_class.new }.should_not raise_error
		end
	end # context

	context "Provided services" do
		it 'should apply its action to the given Lexer' do
      fake_lexeme = mock('lexeme')
      fake_lexeme.should_receive(:clear)

			# Case: create an appropriate mockup Lexer that responds to the specified message
			fake = mock('fake')
      
      # The Lexer is expected receive the lexeme message
			fake.should_receive(:lexeme).and_return(fake_lexeme)
      
			# Create action object
			subject.apply_to(fake)
		end

		it 'should know its child (if any)' do
			subject.children.should be_empty
		end
	end # context

end # describe

describe MutateToken do
  # Rule for creating a default instance called 'subject'
  subject { described_class.new('-', :CHARLIT) }

	context "Creation & initialisation" do
		it 'should be created with a token type' do
			# Error case: created without any argument
			lambda { described_class.new }.should raise_error(ArgumentError, 'wrong number of arguments (0 for 2)')

			# Valid case: created with two token types
			lambda { described_class.new('-', :CHARLIT) }.should_not raise_error
		end
	end # context

	context "Provided services" do
		it 'should apply its action to the given Lexer' do
			# Test sample input data
			token_type_1 = :SOME_TTYPE
			current_lexeme = 'some-text'

			# Case: create an appropriate mockup Lexer that responds to the specified message
			fake = mock('fake')

			# The Lexer is expected receive the undo-scan message
			last = ['-', 'a']
			fake.should_receive(:queue).and_return([last])
			fake.should_receive(:queue).and_return([last])
			fake.should_receive(:queue).and_return([])


			# Create mutation action object
			# Case 1: last token type is matching...
			subject.apply_to(fake)
			last.should == [:CHARLIT, 'a']	# Token type has been modified!...


			# Case 2: last token type is NOT matching...
			last[0] = '+'	# Something different
			subject.apply_to(fake)
			last.should == ['+', 'a']	# Token type has been modified!...

			# Case 3: queue is empty
			lambda { subject.apply_to(fake) }.should_not raise_error
		end

		it 'should know its child (if any)' do
			subject.children.should be_empty
		end
	end # context

end # describe


describe ActionSequence do
	# Return a list of sample actions, just for testing purposes.
	let(:sample_actions) do
    [:T1, :T2, :T3].map { |toktype| EnqueueToken.new(toktype) }
  end

  # Rule for creating a default instance named 'subject'
  subject { described_class.new(sample_actions) }


	context "Creation & initialisation" do

		it "should be created with one or more child actions" do
			# Error case: created with empty action list
			lambda { described_class.new([]) }.should raise_error(StandardError, 'Empty action list.')

			# Valid case: created with a list of actions
			lambda { described_class.new(sample_actions) }.should_not raise_error
		end

		it "should know its sequence of actions" do
			subject.sequence.should == sample_actions
		end
	end

	context "Provided services" do
		it "should know its children" do
			subject.children.should == sample_actions
		end

		it "should apply its actions to the given Lexer" do
			action_list = sample_actions
			instance = described_class.new(action_list)

			# Create an appropriate mockup Lexer that responds to the expected messages
			fake = mock('fake')

			# Check the incoming messages and reply to it
			action_list.each_with_index do |anAction, anIndex|
				ttype = anAction.token_type
				fake.should_receive(:enqueue_token).with(ttype).and_return([ttype, anIndex.to_s])
			end

			result = instance.apply_to(fake)
		end
	end
end # describe



describe ChoiceOnLexeme do
  let(:sample_pattern) { /abc?/ }

	# A couple of sample actions, just for testing purposes.
	let(:sample_actions) do
		[:MATCH_SUCCESS, :MATCH_FAILURE].map { |toktype| EnqueueToken.new(toktype) }
	end
  
  # Rule for creating a default instance named 'subject'
  subject { described_class.new(sample_pattern, *sample_actions) }  

	context "Creation & initialisation" do
		it 'could be created with a string/regexp and one or two actions' do
			# Error case: created without any argument
			lambda { described_class.new }.should raise_error(ArgumentError, 'wrong number of arguments (0 for 2)')

			# Valid case: created with a string and one action only
			lambda { described_class.new('some-text', sample_actions.first) }.should_not raise_error

			# Valid case: created with a string and two actions
			lambda { described_class.new('some-text', *sample_actions) }.should_not raise_error

			# Valid case: created with a regexp and one action only
			lambda { described_class.new(/abc/, sample_actions.first) }.should_not raise_error

			# Valid case: created with a regexp and two actions
			lambda { described_class.new(/abc/, *sample_actions) }.should_not raise_error
		end

		it 'should know its pattern' do
			subject.pattern.should == sample_pattern
		end

		it 'should know the actions to select' do
			# Case 1: both match and non-match actions are provided
			choice1 = subject
			choice1.alternative.should == sample_actions

			# Case 2: only match action is provided
			choice2 = described_class.new(sample_pattern, sample_actions.first)
			choice2.alternative.first.should == sample_actions.first

			# Control the implicit no-match action
			no_match_action = choice2.alternative.last
			no_match_action.should be_nil
		end
	end # context

	context "Provided services" do
		it 'should apply its action to the given Lexer' do
			# Input test data
			sample_text = 'some-text'
			alternative = sample_actions()
			choice_exact = described_class.new(sample_text, *alternative)

			# Case 1: successful exact match...
			fake_lexer = mock('Lexer1')

			# Add behaviour as expected by the actions
			expectation = [:MATCH_SUCCESS, sample_text.dup()]	# Match action should be triggered...
			fake_lexer.should_receive(:enqueue_token).with(:MATCH_SUCCESS).and_return(expectation)
			fake_lexer.should_receive(:lexeme).and_return(sample_text)
			actual = choice_exact.apply_to(fake_lexer)
			actual.should == expectation

			# Case 2: failing exact match...
			another_text = 'non-matching text'
			lexer_two = mock('Lexer2')

			# Add behaviour as expected by the actions
			expectation = [:MATCH_FAILURE, another_text.dup()]	# No-match action should be triggered...
			lexer_two.should_receive(:enqueue_token).with(:MATCH_FAILURE).and_return(expectation)
			lexer_two.should_receive(:lexeme).and_return(another_text)
			actual = choice_exact.apply_to(lexer_two)
			actual.should == expectation

			# Case 3: successful approximate match...
			sample_pattern = /som[ae]/
			choice_approx = ChoiceOnLexeme.new(sample_pattern, *alternative)
			lexer_three = mock('Lexer3')

			# Add behaviour as expected by the actions
			expectation = [:MATCH_SUCCESS, sample_text.dup()]	# Match action should be triggered...
			lexer_three.should_receive(:enqueue_token).with(:MATCH_SUCCESS).and_return(expectation)
			lexer_three.should_receive(:lexeme).and_return(sample_text)
			actual = choice_approx.apply_to(lexer_three)
			actual.should == expectation

			# Case 4: failing approximate match...
			Lexer_four = mock('Lexer4')

			# Add behaviour as expected by the actions
			expectation = [:MATCH_FAILURE, another_text.dup()]	# Match action should be triggered...
			Lexer_four.should_receive(:enqueue_token).with(:MATCH_FAILURE).and_return(expectation)
			Lexer_four.should_receive(:lexeme).and_return(another_text)
			actual = choice_approx.apply_to(Lexer_four)
			actual.should == expectation
		end

		# Advanced & fancy stuff...
		it 'should work with nested choices' do
			# Input test data
			sample_text = 'some text'
			alternative = sample_actions()
			nested_choice = described_class.new(sample_text, *alternative)
			parent_choice = described_class.new(/abc/, EnqueueToken.new(:PARENT_MATCH_SUCCESS), nested_choice)

			# Case 1: successful match at parent choice...
			lexeme1 = 'abcdef'
			fake_lexer = mock('lexer1')

			# Add behaviour as expected by the actions
			fake_lexer.should_receive(:lexeme).and_return(lexeme1)
			expectation = [:PARENT_MATCH_SUCCESS, lexeme1.dup()]	# Match action at parent choice should be triggered...
			fake_lexer.should_receive(:enqueue_token).with(:PARENT_MATCH_SUCCESS).and_return(expectation)
			actual = parent_choice.apply_to(fake_lexer)
			actual.should == expectation

			# Case 2: successful match at nested choice...
			lexer_two = mock('lexer2')

			# Add behaviour as expected by the actions
			lexer_two.should_receive(:lexeme).exactly(2).times.and_return(sample_text)
			expectation = [:MATCH_SUCCESS, sample_text.dup()]	# Match action at parent choice should be triggered...
			lexer_two.should_receive(:enqueue_token).with(:MATCH_SUCCESS).and_return(expectation)
			actual = parent_choice.apply_to(lexer_two)
			actual.should == expectation

			# Case 2: failing match at nested choice...
			different_text = 'non-matchable text'
			lexer_three = mock('lexer3')

			# Add behaviour as expected by the actions
			lexer_three.should_receive(:lexeme).exactly(2).times.and_return(different_text)
			expectation = [:MATCH_FAILURE, different_text.dup()]	# Match action at parent choice should be triggered...
			lexer_three.should_receive(:enqueue_token).with(:MATCH_FAILURE).and_return(expectation)
			actual = parent_choice.apply_to(lexer_three)
			actual.should == expectation
		end

		it 'should know its children' do
			alternative = sample_actions()
			nested_choice = ChoiceOnLexeme.new('some-text', *alternative)
			parent_choice = ChoiceOnLexeme.new(/abc/, EnqueueToken.new(:PARENT_MATCH_SUCCESS), nested_choice)
			nested_choice.children.should == alternative
			parent_choice.children.should == [parent_choice.alternative.first, nested_choice, alternative].flatten
		end

	end # context

end # describe


describe ChangeState do

	context "Creation & initialisation" do
		it 'should be created with a message name, a destination state and an action' do
			# Error case: created without any argument
			lambda { ChangeState.new }.should raise_error(ArgumentError, 'wrong number of arguments (0 for 3)')

			# Valid case: created with a message name, a state, and an action
			lambda { ChangeState.new(:some_message, :SpecialToken, EnqueueToken.new(:SOME_TOKEN) ) }.should_not raise_error
		end

		it 'should know its the message name, the destination and the post-action and its arguments' do
			sample_message = :some_message
			sample_state = :some_state
			sample_action = EnqueueToken.new(:SOME_TOKEN)

			instance = ChangeState.new(sample_message, sample_state, sample_action)
			instance.message.should == sample_message
			instance.args.size.should == 1
			instance.to_state.should == sample_state
			instance.post_action.should == sample_action
		end

		it 'should know its children actions' do
			sample_message = :some_message
			sample_state = :some_state
			sample_action = EnqueueToken.new(:SOME_TOKEN)

			# Case 1: no indirect child
			instance1 = ChangeState.new(:sample_message, sample_state, sample_action)
			instance1.children.should_not be_empty
			instance1.children.first.should == sample_action


			# Case 2: with indirect children
			sample_pattern = /abc?/
			choice = ChoiceOnLexeme.new(sample_pattern, sample_action)
			instance2 = ChangeState.new(:sample_message, sample_state, choice)
			instance2.children.size.should == 2
			instance2.children.first.should == choice
			instance2.children[1].should == sample_action
			implicit_action = instance2.children.last
			implicit_action.should be_kind_of(EnqueueToken)
		end

	end # context

	context "Provided services" do
		it 'should apply its action to the given Lexer' do
			sample_message = :set_state=
			sample_state = :some_state
			sample_action = EnqueueToken.new(:SOME_TOKEN)
			sample_text = 'sample text'

			action = ChangeState.new(sample_message, sample_state, sample_action)

			# Case: create an appropriate mockup Lexer that responds to the specified message
			fake = mock('fake')

			# Check the incoming message and reply to it
			fake.should_receive(sample_message).with(sample_state)

			# Apply the action
			expectation = [:SOME_TOKEN, sample_text]
			fake.should_receive(:enqueue_token).with(:SOME_TOKEN).and_return(expectation)
			action.apply_to(fake).should == expectation
		end
	end # context
end # describe


describe ConditionalActionSequence do

	context "Creation & initialisation" do

		it 'should be created with a Hash of pattern => action' do
			# Correct case
			lambda do ConditionalActionSequence.new /ab/ => EnqueueToken.new(:AB), /cd/ => EnqueueToken.new(:CD) end.should_not raise_error
		end

		it 'should know its sequence of pattern,n action pairs' do
			patt1 = /ab/
			patt2 = /cd/
			action1 = EnqueueToken.new(:AB)
			action2 = EnqueueToken.new(:CD)
			instance = ConditionalActionSequence.new [[patt1, action1], [patt2, action2]]
			instance.sequence.map(&:first).should == [patt1, patt2]
			instance.sequence.map(&:last).should == [action1, action2]
		end

		it 'should know its child actions' do
			patt1 = /ab/
			patt2 = /cd/
			action1 = EnqueueToken.new(:AB)
			action2 = EnqueueToken.new(:CD)
			instance = ConditionalActionSequence.new [[patt1, action1], [patt2, action2]]
			instance.children.should == [action1, action2]
		end

	end

	context "Provided services" do
	end

end # describe

end # module
# End of file