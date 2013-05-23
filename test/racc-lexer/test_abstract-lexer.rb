# File: test_abstract-lexer.rb


require 'pp'
require 'minitest/spec'
require 'minitest/autorun'

require_relative '../../lib/racc-lexer/abstract-lexer' # Load the class under testing


module RaccLexer # Open the namespace in order to avoid long qualified identifiers.

describe AbstractLexer do
  # A constant sample text
  SampleText = 'sample text'

  subject { AbstractLexer.new }

  it 'should be in the proper initial state' do
    position_in_line_state, token_recognition_state = subject.complete_state_name()
    [position_in_line_state, token_recognition_state].must_equal [:at_line_start, :waiting_for_input]
  end

  it 'should ignore identations by default' do
    subject.significant_indentation.wont_equal true
  end

    it 'should consider an eol as a non token by default' do
      subject.eol_as_token.wont_equal true
    end

    it 'should refuse to scan in absence of input text' do
      lambda { subject.next_token() }.must_raise(LexicalError) #, "No input text was provided.")
    end

    it 'should have an empty token queue' do
      subject.queue.must_be_empty
    end



  # context: Providing the input text
    it 'should accept the input as a String argument' do
      subject.input = SampleText
      subject.engine.scanner.string.must_equal SampleText
    end

    it 'should accept the input as a StringScanner argument' do
      stream = StringScanner.new(SampleText)
      subject.input = stream
      subject.engine.scanner.must_equal stream
    end


    it 'should have its low-level scanner correctly initialized' do
      subject.input = SampleText
      subject.engine.scanner.must_be_kind_of(StringScanner)
      subject.engine.scanner.string.must_equal SampleText
    end


    it 'should be in ready state to recognize token(s) in the input stream' do
      subject.input = StringScanner.new(SampleText)
      state = subject.engine.complete_state_name()
      state.must_equal [:at_line_start, :ready]
    end


    it 'should be reset after the text input is given' do
      subject.input = StringScanner.new(SampleText)
      subject.engine.lineno.must_equal 1
      subject.engine.line_offset.must_equal 0
      subject.queue.must_be_empty
    end


=begin

  # test each state machine independently of the other
  # First, consider all the states of line_positioning STM
  # Second, all the state of token_recognition STM
  # Third one tries a set of scenarios based on the line_pattern syntax_diagram.
  # Lastly, one controls the indentation management
  ######################################

  ######################################
  # Underlying test assumption: the lexemes in a text line occur
  # according to the syntax diagram:
  # ()->+----------------->+-->+-->+------------>+-->+-->+-- eol -->+-->()
  #     |                  ^   ^   |             ^   |   |          ^
  #     v                  |   |   v             |   |   v          |
  #     +-- indentation -->+   |   +--> noise -->+   |   +-- eos -->+
  #                            |                     |
  #                            |                     v
  #                            +<------ token <------+
  #
  # Test strategy
  # -Empty input testing.
  # -Single line input testing. Derive test cases from the line pattern (diagram above).
  #   Do it for languages that are indentation/line sensitive or not.
  # -Multiple lines input testing. More specifically: test indentation management, multi-line tokens

  # The following list enumerates the plausible test cases for:
  # -Empty input testing
  # -Single line input testing

=begin
|1|eos|
|2|eol|
|3|noise|eos|
|4|noise|eol|
|5|token|eos|
|6|token|eol|
|7|noise|token|eos|
|8|noise|token|eol|
|9|token|noise|eos|
|10|token|noise|eol|
|11|token|token|eos|
|12|token|token|eol|
|13|noise|token|noise|eos|
|14|noise|token|noise|eol|
|15|noise|token|token|eos|
|16|noise|token|token|eol|
|17|token|noise|token|eos|
|18|token|noise|token|eol|
|19|token|token|noise|eos|
|20|token|token|noise|eol|
|21|noise|token|noise|token|eos|
|22|noise|token|noise|token|eol|
|23|noise|token|token|noise|eos|
|24|noise|token|token|noise|eol|
|25|token|noise|token|noise|eos|
|26|token|noise|token|noise|eol|
|27|indentation|eos|
|28|indentation|eol|
|29|indentation|noise|eos|
|30|indentation|noise|eol|
|31|indentation|token|eos|
|32|indentation|token|eol|
|33|indentation|noise|token|eos|
|34|indentation|noise|token|eol|
|35|indentation|token|noise|eos|
|36|indentation|token|noise|eol|
|37|indentation|token|token|eos|
|38|indentation|token|token|eol|
|39|indentation|noise|token|noise|eos|
|40|indentation|noise|token|noise|eol|
|41|indentation|noise|token|token|eos|
|42|indentation|noise|token|token|eol|
|43|indentation|token|noise|token|eos|
|44|indentation|token|noise|token|eol|
|45|indentation|token|token|noise|eos|
|46|indentation|token|token|noise|eol|
|47|indentation|noise|token|noise|token|eos|
|48|indentation|noise|token|noise|token|eol|
|49|indentation|noise|token|token|noise|eos|
|50|indentation|noise|token|token|noise|eol|
|51|indentation|token|noise|token|noise|eos|
|52|indentation|token|noise|token|noise|eol|
=end



#####################
# Defining a lexer subclass to test lexical analysis of a (simplified) line oriented language
#####################
class Lexer4LineOriented < AbstractLexer


public
  # Concrete method implementation.
  # Returns a regular expression that matches non-significant text.
  # Whitespaces or comments.
  def noise_pattern()
    return /(?: |\t)*(?:#.*)?/  # zero or more [space, tab] possibly followed by a line comment (starting with a '#' character)
  end

end # class


describe Lexer4LineOriented do
  # Factory method.
  subject do
    instance = Lexer4LineOriented.new
    instance.significant_indentation = true
    instance
  end

=begin
  ################
  context "in 'at_line_start' state" do
    it 'should accept the scan_indentation message' do
      # Case of no indentation
      subject.input = "123"
      subject.send(:scan_indentation)

      # Test the state after event handling
      subject.complete_state_name.should == [:at_line_start, :ready]


      # Case of indentation present
      instance = Lexer4LineOriented.new
      instance.significant_indentation = true
      instance.input = "    123"
      instance.send(:scan_indentation)

      # Test the state after event handling
      instance.complete_state_name.should == [:after_indentation, :ready]

    end
  end # context
=end
end # describe

=begin
  ################
  context 'Single line input (for line-oriented language)' do
  end # context





  # Considering the states of line_positioning STM
  context "in 'at_line_start' state" do
    it 'should reject to indentation_scanned event (when indentations are ignored)' do
      # Firing the invalid event under testing ...
      lambda { subject.indentation_scanned() }.should raise_error
    end



    it 'should accept the eol_checked' do
      # Consider eol as a token (to emit)
      subject.eol_as_token = true

      # Firing the event under testing ...
      subject.eol_checked()

      # Test the state after event handling
      subject.complete_state_name.should == [:at_line_end, :waiting_for_token]
      # TODO: check that eol token is emitted.
    end

    it 'should accept the expected_char_checked' do
      # Firing the event under testing ...
      subject.expected_char_checked()

      # Test the state after event handling
      subject.complete_state_name.should == [:in_line_body, :ready]
      # TODO: check that handle indentation is performing correctly.
    end

  end # context

  context "in 'after_indentation' state" do
  # Construction of default instance object named 'subject'
    subject do
      instance = AbstractLexer.new
      instance.significant_indentation = true
      instance.indentation_scanned()

      instance
    end

    it 'should reject the indentation_scanned event' do
      # Firing the invalid event under testing ...
      error_message = "No transition found for event i_indentation_scanned"
      lambda { subject.indentation_scanned() }.should raise_error(EdgeStateMachine::NoTransitionFound, error_message)
    end

    it 'should accept the eol_checked' do
      # Consider eol as a token (to emit)
      subject.eol_as_token = true

      # Firing the event under testing ...
      subject.eol_checked()

      # Test the state after event handling
      subject.complete_state_name.should == [:at_line_end, :waiting_for_token]
      # TODO: check that eol token is emitted.
    end


    it 'should accept the expected_char_checked' do
      # Firing the event under testing ...
      subject.expected_char_checked()

      # Test the state after event handling
      subject.complete_state_name.should == [:in_line_body, :ready]
      # TODO: check that handle indentation is performing correctly.
    end

  end # context


  context "in 'in_line_body' state" do

  # Construction of default instance object named 'subject'
    subject do
      instance = AbstractLexer.new()
      instance.expected_char_checked()

      instance
    end

    it 'should unconditionally reject the indentation_scanned event' do
      subject.significant_indentation = true

      # Firing the invalid event under testing ...
      error_message = "No transition found for event i_indentation_scanned"
      lambda { subject.indentation_scanned() }.should raise_error(EdgeStateMachine::NoTransitionFound, error_message)
    end

    it 'should accept the eol_checked' do
      # Consider eol as a token (to emit)
      subject.eol_as_token = true

      # Firing the event under testing ...
      subject.eol_checked()

      # Test the state after event handling
      subject.complete_state_name.should == [:at_line_end, :ready]
      # TODO: check that eol token is emitted.
    end


    it 'should accept the expected_char_checked' do
      # Firing the event under testing ...
      subject.expected_char_checked()

      # Test the state after event handling
      subject.complete_state_name.should == [:in_line_body, :ready]
      # TODO: check that handle indentation is performing correctly.
    end
  end # context


  context "in 'at_line_end' state" do

  # Construction of default instance object named 'subject'
    subject do
      instance = AbstractLexer.new()
      instance.eol_checked()

      instance
    end

    it 'should reject the indentation_scanned event even when indentation are significant' do
      subject.significant_indentation = true

      # Firing the invalid event under testing ...
      error_message = "No transition found for event i_indentation_scanned"
      lambda { subject.indentation_scanned() }.should raise_error(EdgeStateMachine::NoTransitionFound, error_message)
    end

    it 'should accept the eol_checked' do
      # Consider eol as a token (to emit)
      subject.eol_as_token = true

      # Firing the event under testing ...
      subject.eol_checked()

      # Test the state after event handling
      subject.current_state_name(:line_positioning).should == :at_line_end
      # TODO: check that eol token is emitted.
    end


    it 'should reject the expected_char_checked' do
      # Firing the invalid event under testing ...
      error_message = "No transition found for event expected_char_checked_stm_line"
      lambda { subject.expected_char_checked() }.should raise_error(EdgeStateMachine::NoTransitionFound, error_message)
    end


    it 'should accept the not_eol_checked event' do
      subject.not_eol_checked

      # Test the state after event handling
      subject.current_state_name(:line_positioning).should == :at_line_start
    end

  end # context


  # Considering the states of token_recognition STM
  context "in 'waiting_for_token' state" do
    it 'should accept the eol_detected event' do
      # Fire the event under testing ...
      subject.eos_detected()

      subject.current_state_name(:token_recognition).should == :done
    end

    it 'should accept the expected_char_checked event' do
      # Fire the event under testing ...
      subject.expected_char_checked()

      subject.current_state_name(:token_recognition).should == :ready
    end
  end # context


  context "in 'ready' state" do
    # Construction of default instance object named 'subject'
    subject do
      instance = AbstractLexer.new()
      instance.expected_char_checked()

      instance
    end


    it 'should accept the token_recognized event' do
      # Fire the event under testing ...
      subject.token_recognised()

      subject.current_state_name(:token_recognition).should == :recognised
    end

    it 'should accept the eol_detected event' do
      # Fire the event under testing ...
      subject.eos_detected()

      subject.current_state_name(:token_recognition).should == :done
    end

    it 'should accept the unexpected_char_checked' do
      # Fire the event under testing ...
      subject.unexpected_char_checked()

      subject.current_state_name(:token_recognition).should == :failed
    end
  end # context


  context "in 'recognised' state" do
    # Construction of default instance object named 'subject'
    subject do
      instance = AbstractLexer.new()
      instance.expected_char_checked()
      instance.token_recognised()

      instance
    end


    it 'should accept the token_enqueued event' do
      # Fire the event under testing ...
      subject.token_enqueued()

      subject.current_state_name(:token_recognition).should == :waiting_for_token
    end

  end # context


  context 'lexemes occurring in text lines' do
    # Assumption: the lexemes in a text line occur
    # ccording to the syntax diagram:
    # ()->+----------------->+-->+-->+------------>+-->+-->+-- eol -->+-->()
    #     |                  ^   ^   |             ^   |   |          ^
    #     v                  |   |   v             |   |   v          |
    #     +-- indentation -->+   |   +--> noise -->+   |   +-- eos -->+
    #                            |                     |
    #                            |                     v
    #                            +<------ token <------+

    it 'should accept eos as input' do
      subject.eos_detected

    end

  end # context

=end
=begin
end # describe


#####################
# Defining a lexer subclass to test lexical analysis of a (simplified) block delimited language
#####################
class Lexer4BlockDelimited < AbstractLexer

public
  # Concrete method implementation.
  # Returns a regular expression that matches non-significant text.
  # Whitespaces or comments.
  def noise_pattern()
    return /(?: |\t)*(?:#.*)?/  # zero or more [space, tab] possibly followed by a line comment (starting with a '#' character)
  end

end # class



describe Lexer4BlockDelimited do

  ################ CONTEXT
  context 'Empty input testing' do
    # Overriding the construction of an object named 'subject'
    subject {
      instance = Lexer4BlockDelimited.new
      instance.input = ''
      instance
    }

    it 'should return the eos marker' do
			actual_result = subject.next_token()

      expected_result = [false, ['$', [0, 1]]]	# eos token at position: offset = 0, lineno = 1
			actual_result.should == expected_result
    end

    it "should be in state 'done' after gobbling the eos" do
      subject.next_token()
      subject.token_recognition_state.should == :done
    end
  end # context

  ################ CONTEXT
  context 'Single line input' do
    it 'should handle a line consisting of 0..1 noise followed by a eos or eol (TC2, TC3, TC4)' do
      test_vectors = [
        #[ input,         [ expected_offset, expected_lineno ] ]
        [ "\n",           [1, 2] ], # TC2
        [ "  #comment",  [10, 1] ], # TC3
        [ "  #comment\n",[11, 2] ]  # TC4
      ]

      test_vectors.each do |(input_text, expected_pos)|
        subject.input = input_text
        actual_result = subject.next_token()

        # Expect to return an eos
        expected_result = [false, ['$', expected_pos]]	# eos token at position: offset = 1, lineno = 2
        actual_result.should == expected_result

        # Should be in state 'done' after gobbling the eol
        subject.token_recognition_state.should == :done
      end
    end


  end # context
=end
end # describe

end # module
# End of file