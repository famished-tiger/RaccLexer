# File: test_lexer-engine.rb

require 'pp'
require 'minitest/spec'
require 'minitest/autorun'

require_relative '../../lib/racc-lexer/lexer-engine'  # The class under testing

# Custom MiniTest assertion
module MiniTest::Assertions

  # Assert that the engine is in given state
  # [anEngine] a LexerEngine under testing.
  # [aggregateState] an array with the expected state names
  def assert_in_state(anEngine, aggregateState)
    current_state = anEngine.complete_state_name()
    error_message = "Expected lexer engine to be in state #{aggregateState} instead of #{current_state}"
    assert( (current_state == aggregateState || current_state.reverse == aggregateState), error_message)
  end

end # module


# Custom MiniTest/Spec expectation
module MiniTest::Expectations
  infect_an_assertion :assert_in_state, :must_be_in_state, :reverse
end # module



class TestLexerEngine < MiniTest::Unit::TestCase

  # Test setup
  def setup()
    @subject = RaccLexer::LexerEngine.new # Create a blank instance
    @sample_text = "  123 + 456;"
  end

  # Testing the post-conditions
  def test_initialize()
    # Is the engine in the proper state machine state?
    assert_in_state(@subject, [:at_line_start, :waiting_for_input])

    # No scanner was specified yet...
    assert_nil @subject.scanner

    # No token position determined yet...
    assert_nil @subject.lineno
    assert_nil @subject.line_offset

    # No lexeme found yet...
    assert_nil @subject.lexeme
  end

  # TODO: check correctness of behaviour for all states.
  def test_input=()
    @subject.input = @sample_text

    # Is the engine in the proper state machine state?
    assert_in_state(@subject, [:at_line_start, :ready])

    # A scanner is associated with the input text
    refute_nil @subject.scanner
    assert @subject.scanner.string == @sample_text

    # Position is set to begin
    assert @subject.lineno == 1
    assert @subject.line_offset == 0

    # attribute lexeme initialized to empty string
    assert_empty @subject.lexeme
  end

end # class




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


describe "TC1: |eos|" do
  subject do
    lexer = RaccLexer::LexerEngine.new
    lexer.input = ''
    lexer
  end

  it 'should detect empty input text' do
    assert subject.eos?
  end

  it 'should return the eos marker after scanning once' do
    actual_token = subject.scan(/.+/)
    actual_token.must_equal :eos

    # Must be in end of stream state
    subject.must_be_in_state([:at_line_start, :done])
  end

  it 'should complain when trying to scan after eos detection' do
    subject.scan(/.+/)  # eos is returned here...

    # Scanning AFTER the eos marker was already returned generates an exception
    lambda { subject.scan(/.+/) }.must_raise RaccLexer::LexicalError
  end
end # describe


describe "TC2: |eol|" do
  subject do
    lexer = RaccLexer::LexerEngine.new
    lexer.input = "\n"
    lexer
  end

  it 'should return the eol token after scanning once' do
    actual_token = subject.scan(/.+/)
    actual_token.must_equal :eol

    subject.lexeme.must_match /\r?\n/

    # Must ready for another token
    subject.must_be_in_state([:at_line_end, :ready])
  end

  it 'should complain when trying to scan after eol detection' do
    actual_token = subject.scan(/.+/)
    actual_token.must_equal :eol

    # AFTER the eol, we expect an eos
    second_token = subject.scan(/.+/)
    second_token.must_equal :eos
  end

end #describe

describe "TC3: |noise|eos|" do
  subject do
    lexer = RaccLexer::LexerEngine.new
    lexer.input = "# Some comment"
    lexer
  end

  it 'should return the eos marker after scanning once' do
    actual_token = subject.scan(/.+/)
    actual_token.must_equal :eos

    # Must be in end of stream state
    subject.must_be_in_state([:at_line_start, :done])
  end
end #describe


describe "TC4: |noise|eol|" do
  subject do
    lexer = RaccLexer::LexerEngine.new
    lexer.input = "# Some comment\n"
    lexer
  end

  it 'should return the eol token after scanning once' do
    actual_token = subject.scan(/.+/)
    actual_token.must_equal :eol

    subject.lexeme.must_match /\r?\n/

    # Must ready for another token
    subject.must_be_in_state([:at_line_end, :ready])
  end

  it 'should return eos after eol detection' do
    actual_token = subject.scan(/.+/)
    actual_token.must_equal :eol

    # AFTER the eol, we expect an eos
    second_token = subject.scan(/.+/)
    second_token.must_equal :eos
  end
end # describe



describe "Test cases: TC5, TC7, TC9, TC13" do
  before do
    @sample_inputs = ["12345",  # TC5: |token|eos|
      "/* A comment */12345",   # TC7: |noise|token|eos|
      "12345/* A comment */",   # TC9: |token|noise|eos|
      "/* comment1*/12345# comment2"   # TC13:|noise|token|noise|eos|
    ]
  end

  it 'should return the integer token after scanning once' do
    @sample_inputs.each do |sample|
      instance = RaccLexer::LexerEngine.new
      instance.input = sample
      actual_token = instance.scan(/\d+/)  # Read any ordinal literal
      actual_token.must_equal :token

      instance.lexeme.must_equal "12345"

      # Must be ready for next token...
      instance.must_be_in_state([:in_line_body, :recognized])
    end
  end

  it 'should return eos after token detection' do
    @sample_inputs.each do |sample|
      instance = RaccLexer::LexerEngine.new
      instance.input = sample
      actual_token = instance.scan(/\d+/)
      actual_token.must_equal :token

      # AFTER the token, we expect an eos
      second_token = instance.scan(/.+/)
      second_token.must_equal :eos
    end
  end

end #describe


describe "TC6, TC8, TC10, TC14" do
  before do
    @sample_inputs = ["12345\n",  # TC6: |token|eol|
      "/* A comment */12345\n",   # TC8: |noise|token|eol|
      "12345/* A comment */\n",   # TC10: |token|noise|eol|
      "/*comment1*/12345/*comment2*/\n" # TC14: |noise|token|noise|eol|
    ]
  end

  it 'should return the integer token after scanning once' do
    @sample_inputs.each do |sample|
      instance = RaccLexer::LexerEngine.new
      instance.input = sample
      actual_token = instance.scan(/\d+/)  # Read any ordinal literal
      actual_token.must_equal :token

      instance.lexeme.must_equal "12345"

      # Must be ready for next token...
      instance.must_be_in_state([:in_line_body, :recognized])
    end
  end

  it 'should return eol after token detection' do
    @sample_inputs.each do |sample|
      instance = RaccLexer::LexerEngine.new
      instance.input = sample
      actual_token = instance.scan(/\d+/)
      actual_token.must_equal :token

      # AFTER the token, we expect an eol
      second_token = instance.scan(/.+/)
      second_token.must_equal :eol
    end
  end

end #describe




describe "Test cases: TC11, TC15, TC17, TC19, TC21, TC23, TC25" do
  before do
    @sample_inputs = ["12345*",   # TC11: |token|token|eos|
      "/*comment*/12345*",        # TC15: |noise|token|token|eos|
      "12345/*comment*/*",        # TC17: |token|noise|token|eos|  
      "12345*/*comment*/",        # TC19: |token|token|noise|eos|
      "/*comment1*/12345/*comment2*/*",   # TC21: |noise|token|noise|token|eos|
      "/*comment1*/12345*/*comment2*/",   # TC23: |noise|token|token|noise|eos| 
      "12345/*comment1*/*/*comment2*/"    # TC25: |token|noise|token|noise|eos|       
    ]
    @token_pattern = /\d+|[-+*\/]/  # Read ordinal literal or arith. operator
    @expected_lexemes = %w[12345 *]
  end

  it 'should return the two tokens' do 
    @sample_inputs.each do |sample|
      instance = RaccLexer::LexerEngine.new
      instance.input = sample
      @expected_lexemes.each do |expected|
        actual_token = instance.scan(@token_pattern) 
        actual_token.must_equal :token

        instance.lexeme.must_equal expected

        # Must be ready for next token...
        instance.must_be_in_state([:in_line_body, :recognized])
      end
    end
  end

  it 'should return eos after the two detected tokens' do
    @sample_inputs.each do |sample|
      instance = RaccLexer::LexerEngine.new
      instance.input = sample
      2.times do
        actual_token = instance.scan(@token_pattern)
        actual_token.must_equal :token
      end

      # AFTER the token, we expect an eos
      second_token = instance.scan(/.+/)
      second_token.must_equal :eos
      instance.must_be_in_state([:in_line_body, :done])
    end
  end

end #describe



describe "Test cases: TC12, TC16, TC18, TC20, TC22, TC24, TC26" do
  before do
    @sample_inputs = ["12345*\n",  # TC12: |token|token|eol|
      "/*comment*/12345*\n",       # TC16: |noise|token|token|eol|
      "12345/*comment*/*\n",        # TC18: |token|noise|token|eol|
      "12345*/*comment*/\n",        # TC20: |token|token|noise|eol|
      "/*comment1*/12345/*comment2*/*\n",        # TC22: |noise|token|noise|token|eol|
      "/*comment1*/12345*/*comment2*/\n",        # TC24: |noise|token|token|noise|eol|
      "12345/*comment1*/*/*comment2*/\n"         # TC26: |token|noise|token|noise|eol|      
    ]
    @token_pattern = /\d+|[-+*\/]/  # Read ordinal literal or arith. operator
    @expected_lexemes = %w[12345 *]
  end

  it 'should return the two tokens' do 
    @sample_inputs.each do |sample|
      instance = RaccLexer::LexerEngine.new
      instance.input = sample
      @expected_lexemes.each do |expected|
        actual_token = instance.scan(@token_pattern) 
        actual_token.must_equal :token

        instance.lexeme.must_equal expected

        # Must be ready for next token...
        instance.must_be_in_state([:in_line_body, :recognized])
      end
    end
  end

  it 'should return eol after the two detected tokens' do
    @sample_inputs.each do |sample|
      instance = RaccLexer::LexerEngine.new
      instance.input = sample
      2.times do
        actual_token = instance.scan(@token_pattern)
        actual_token.must_equal :token
      end

      # AFTER the token, we expect an eos
      second_token = instance.scan(/.+/)
      second_token.must_equal :eol
      instance.must_be_in_state([:at_line_end, :ready])
    end
  end

end #describe



=begin
describe "Test cases: TC27" do
  before do
    @indentation = ' ' * 4
    @sample_inputs = [ @indentation  # TC27: |indentation|eos|
    ]
  end

  it 'should return the integer token after scanning once' do
    @sample_inputs.each do |sample|
      instance = RaccLexer::LexerEngine.new
      instance.input = sample
      actual_token = instance.scan(/.+/)  # Read any token
      actual_token.must_equal :indentation

      instance.lexeme.must_equal @indentation

      # Must be ready for next token...
      instance.must_be_in_state([:after_indentation, :recognized])
    end
  end

  it 'should return eos after token detection' do
    @sample_inputs.each do |sample|
      instance = RaccLexer::LexerEngine.new
      instance.input = sample
      actual_token = instance.scan(/.+/)
      actual_token.must_equal :indentation

      # AFTER the token, we expect an eos
      second_token = instance.scan(/.+/)
      second_token.must_equal :eos
    end
  end

end #describe
=end

# End of file