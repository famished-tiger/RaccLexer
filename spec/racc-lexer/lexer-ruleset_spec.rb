# File: lexer-rule_spec.rb

require 'pp'
require 'stringio'
require_relative '../rspec_helper'
require_relative '../../lib/racc-lexer/lexer-rule'
require_relative '../../lib/racc-lexer/lexer-ruleset'  # The class under test


# Reopen the module, in order to get rid of fully qualified names
module RaccLexer	# This module is used as a namespace
  describe LexerRuleset do

  # This builds a sample lexer rule
  let(:rule1) do
    rule = StandardRule.new(:first_rule, nil)

    # Adding handlers...
    rule.add_handler(EventHandler.new('&', EnqueueToken.new(:T_AND)))
    rule.add_handler(EventHandler.new('|', EnqueueToken.new(:T_OR)))


    rule
  end

  # This builds another sample lexer rule
  let(:rule2) do
    rule = LookaheadRule.new(:second_rule)

    rule.add_handler(EventHandler.new(/=>/, EnqueueToken.new(:T_IMPLIES)))
    rule.add_handler(EventHandler.new(/<=>/, EnqueueToken.new(:T_EQUIVALENCE)))

    rule
  end


  context "Creation & initialisation" do
    it 'should be created without argument' do
      # Valid case: create with a rule name
      lambda { LexerRuleset.new }.should_not raise_error
    end

    it "should be empty" do
      subject.should be_empty
      subject.size.should == 0
    end

    it 'should not have registered token types' do
      subject.token_types.should be_nil
    end
	end # context

  context "Provided services" do
    # Build a Hash with Token type (asSymbol) => 'A descriptive text'
    let(:sample_token_types) do
      { :T_TRUE => 'Literal value true',
        :T_FALSE => 'Literal value false',
        :T_AND => 'Logical conjunction',
        :T_OR => 'Logical disjunction',
        :T_IMPLIES => 'Logical implication',
        :T_EQUIVALENCE => 'Logical equivalence'
       }
    end

    it "should register token types" do
      # Valid: register once...
      subject.token_types = sample_token_types
      subject.token_types.should == sample_token_types

      # Invalid: registering a second time...
      error_message = "Token types can be specified only once."
      lambda { subject.token_types = sample_token_types }.should raise_error(LexerSetupError, error_message)
    end

    it "should know its rules" do
      subject.token_types = sample_token_types
      subject.should have(0).rules

      subject.add_rule(rule1)
      subject.should have(1).rules
      subject.rules.values.first.should == rule1

      subject.add_rule(rule2)
      subject.should have(2).rules
      subject.rules.values.last.should == rule2
    end


    it "should emit a list of registered token to an output stream" do
      output = StringIO.new('', 'w')
      subject.token_types = sample_token_types
      subject.declare_tokens(output)

      expectation = <<-EOS
# Declare the tokens (terminal symbols) registered in the lexer.
# Remark special characters are returned 'as is'
token
  T_AND    # Logical conjunction
  T_EQUIVALENCE    # Logical equivalence
  T_FALSE    # Literal value false
  T_IMPLIES    # Logical implication
  T_OR    # Logical disjunction
  T_TRUE    # Literal value true
EOS

    actual = output.string
    actual.gsub!(/\t/, '  ')  # Replace tabs by two spaces...
    actual.should == expectation

    end



    it "should complain when adding a rule without registered token types" do
      error_message = "The rule set has no token types defined"
      lambda { subject.add_rule(rule1) }.should raise_error(LexerRuleError, error_message)
    end


    it "should complain in case of rule name collision" do
      # Here the token types are registered
      subject.token_types = sample_token_types

      # Valid
      subject.add_rule(rule1)
      subject.add_rule(rule2)

      # Invalid: attempting to add rule with same name
      error_message = "Two tokenizing rules may not have the same name first_rule."
      lambda { subject.add_rule(rule1) }.should raise_error(LexerRuleError, error_message)
    end


    it "should validate all rules" do
      subject.token_types = sample_token_types

      # Valid
      subject.add_rule(rule1)

      # Add an event handler to the first rule.
      # The event handler recognizes an unregistered token type
      rule2.add_handler(EventHandler.new('+', EnqueueToken.new(:T_PLUS)))

      #Invalid...
      error_message = "Rule 'second_rule' refers to unknown token type 'T_PLUS'"
      lambda { subject.add_rule(rule2) }.should raise_error(LexerRuleError, error_message)
    end
  end

end # describe

end # module
# End of file