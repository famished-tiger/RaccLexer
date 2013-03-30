# encoding: utf-8 -- You should see a paragraph character: §
# File: lexer-rule-dsl_spec.rb


require_relative '../rspec_helper'
require_relative '../../lib/racc-lexer/lexer-rule-dsl' # Load the class under testing

# Reopen the module, in order to get rid of fully qualified names
module RaccLexer	# This module is used as a namespace

module Scanning	# This module is used as a namespace

describe LexerRuleDsl do
	
	context 'Creation & initialization' do
		
		it 'should be created without parameter' do
			lambda { LexerRuleDsl.new }.should_not raise_error
		end
		
		it 'should have an empty ruleset' do
			 instance = LexerRuleDsl.new
			 instance.ruleset.should be_empty
			 lambda { instance.ruleset.validate }.should_not raise_error
		end
		
	end # context
	

	context 'provided services' do

		it 'should complain when rules method has no block argument' do
			lambda { LexerRuleDsl.ruleset }.should raise_error(ArgumentError, 'block not supplied')
		end		

		it 'should allow a rule with token and choice actions' do
			ruleset = LexerRuleDsl.ruleset do
				tokens :LOOKBEHIND_POS => 'Text',
					:LOOKBEHIND_NEG => 'Text',
					:NAMED_GROUP => 'Text',
					"'" => 'Text',
					:T1 => 'Text',
					:T2 => 'Text'
					
				rule(:special_group_expr) do		
					on '=' => recognize(:LOOKBEHIND_POS)
					on '!' => recognize(:LOOKBEHIND_NEG)
					on /\w/ => choice(/\w*\>/, recognize(:NAMED_GROUP))
					on /'/ => pattern_seq(/\w+/ => recognize(:NAMED_GROUP), /'/ => recognize("'"))
					on 'z' => procedure([recognize(:T1), recognize(:T2)])
				end
			end
			
			lambda { ruleset.validate }.should_not raise_error
			ruleset.size.should == 1
			aRule = ruleset[:special_group_expr]
			aRule.should be_kind_of(StandardRule)
			aRule.name.should == :special_group_expr
			aRule.should have(5).handlers
			
			# Check the result of the on method
			first_handler = aRule.handlers.first
			first_handler.should be_kind_of(EventHandler)
			first_handler.pattern.should == '='
			
			# Check the result of the token method
			first_action = first_handler.action
			first_action.should be_kind_of(EnqueueToken)
			first_action.token_type.should == :LOOKBEHIND_POS
			
			# Check the result of the token method
			second_action = aRule.handlers[1].action
			second_action.should be_kind_of(EnqueueToken)
			second_action.token_type.should == :LOOKBEHIND_NEG			
			
			# Check the result of the choice method
			aRule.handlers[-3].pattern.should == /\w/
			choice_action = aRule.handlers[-3].action
			choice_action.should be_kind_of(ChoiceOnLookahead)
			choice_action.alternative.first.should be_kind_of(EnqueueToken)
			choice_action.alternative.first.token_type.should == :NAMED_GROUP
			
			# Check the result of the pattern_seq method
			forelast_action = aRule.handlers[-2].action
			forelast_action.should be_kind_of(ConditionalActionSequence)
			forelast_action.should have(2).children
			
			# Check the result of the procedure method
			last_action = aRule.handlers.last.action
			last_action.should be_kind_of(ActionSequence)
			last_action.should have(2).children
		end
		
		it 'should allow a rule with change state action' do
			sample_method = :state=
			destination_state = :IN_CCLASS
			sample_token = :SOME_TOKEN
			
			ruleset = LexerRuleDsl.ruleset do
				tokens :SOME_TOKEN => 'Text'
				
				rule(:state_changing_rule) do		
					on '[' => change_state(sample_method, destination_state, recognize(sample_token))
				end
			end
			
			lambda { ruleset.validate }.should_not raise_error
			ruleset.size.should == 1
			aRule = ruleset[:state_changing_rule]
			aRule.should be_kind_of(StandardRule)
			aRule.name.should == :state_changing_rule
			aRule.should have(1).handlers
			
			# Check the result of the on method
			first_handler = aRule.handlers.first
			first_handler.should be_kind_of(EventHandler)
			first_handler.pattern.should == '['
			
			# Check the result of the token method
			first_action = first_handler.action
			first_action.should be_kind_of(ChangeState)
			first_action.message.should == sample_method
			first_action.to_state.should == destination_state
			first_action.post_action.should be_kind_of(EnqueueToken)
		end		
		
		it 'should allow a rule with sub-rules' do
			ruleset = LexerRuleDsl.ruleset do
				tokens :PREDEFINED_CCLASS => "Text",
					:CHARLIT => "Text",
					:ANCHOR => "Text",
					:NUM_BACKREF => "Text"
				
				rule(:escape_char) do
					on /[dDhHsSwW]/ => recognize(:PREDEFINED_CCLASS) # ...it is a pre-defined character class
					on /[aefnrtv]/ => recognize(:CHARLIT) # ... it is a control character
					on /[AbBGzZ]/ => recognize(:ANCHOR) # ...Is it an anchor
					on 'x' => choice(/[0-9a-fA-F]{1,2}/, recognize(:CHARLIT)) # ... It is one ore two hex digits codepoint
					on 'u' => choice(/\h{4}|\{\h+\}/, recognize(:CHARLIT))	# ... It is an Unicode codepoint sequence
					on 'k' => subrule(:backreference)	# ... It is a backreference to a numbered or named capturing group
					on 'g' => subrule(:invokation)	# ... It is a invokation to a numbered or named capturing group
					on /[1-9]/ => choice(/\d*/, recognize(:NUM_BACKREF))	# ... It is a backreference to a numbered capturing group
					otherwise method(:build_token, :CHARLIT) # ... It is a single escaped character
				end
			end
			ruleset.size.should == 1
			
			# incomplete ruleset ... our validation should detect this...
			lambda { ruleset.validate }.should raise_error(StandardError, "Reference to unknown subrule 'backreference' in rule 'escape_char'.")
			
			aRule = ruleset[:escape_char]
			
			# Control the output of the subrule method
			sixth_handler = aRule.handlers[5]
			sixth_handler.pattern.should == 'k'
			sixth_handler.action.should be_kind_of(ApplySubrule)
			sixth_handler.action.rulename.should == :backreference
			
			# Control the output of the otherwise method
			aRule.default_action.should be_kind_of(SendMessageAction)
			aRule.default_action.message.should == :build_token
			aRule.default_action.args.should == [:CHARLIT]
		end	

		it 'should allow lookahead rule creation' do
			ruleset = LexerRuleDsl.ruleset do
				tokens :NUM_INVOKATION => 'Text',
					:NUM_REL_INVOKATION => 'Text',
					:NAME_INVOKATION => 'Text'
			
				lookahead_rule(:invokation_std_syntax) do
					# Remark: we added parentheses otherwise the sintax hightlighting was fooled...
					on(/\d+>/ => recognize(:NUM_INVOKATION))
					on(/-\d+>/ => recognize(:NUM_REL_INVOKATION))
					on(/\w+>/ => recognize(:NAME_INVOKATION))
				end
			end
			
			ruleset.size.should == 1
			lambda { ruleset.validate }.should_not raise_error
			aRule = ruleset[:invokation_std_syntax]
			aRule.should be_kind_of(LookaheadRule)
			aRule.name.should == :invokation_std_syntax
			aRule.handlers.size.should == 3
		end

		
		it 'should allow multiple rule creation' do
			ruleset = LexerRuleDsl.ruleset do
				tokens :NON_CAPTURING_GROUP => 'Text',
					:ATOMIC_GROUP => 'Text',
					:LOOKAHEAD_POS => 'Text',
					:LOOKAHEAD_NEG => 'Text',
					:NAMED_GROUP => 'Text',
					'('	=> 'Text'
				
				lookahead_rule(:main) do	
					on "\\" => subrule(:escape_char)
					on "(?" => subrule(:group_expr)
					on '(' => recognize('(')
					on '{' => putback()
					otherwise method(:scan_single_char)	
				end

				rule(:group_expr) do
					on ':' => recognize(:NON_CAPTURING_GROUP)
					on '>' => recognize(:ATOMIC_GROUP)
					on '=' => recognize(:LOOKAHEAD_POS)
					on '!' => mutate('-' => :LOOKAHEAD_NEG)
					on '<' => subrule(:special_group_expr)
					on "'"	=> choice(/\w+'/, recognize(:NAMED_GROUP))
				end				
			end
		end				
		
	end # context


end # describe

end # module

end # module

# End of file