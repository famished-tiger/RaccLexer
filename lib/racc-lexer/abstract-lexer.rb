# File: abstract-lexer.rb

require "pp"

require_relative '../abstract-method'
require_relative 'lexer-engine'
require_relative 'token'
require_relative 'token-queue'

module RaccLexer	# This module is used as a namespace


class AbstractLexer
  include AbstractMethod   # Mixin module to mark some methods as abstract

  # State-machines that keep track of the state wrt. position in line, token recognition
  attr_reader(:engine)

	# A FIFO queue of tokens. Since the lexer can enqueue multiple tokens at once,
	# the queue reduces the need to keep the lexer's state between next_token invokation.
	attr_reader(:queue)

  # A boolean that indicates whether the lexer should treat indentations as significant or
  # ignored. When indentations are significant, they are treated as particular tokens.
  attr(:significant_indentation, true)

  # A boolean that indicates whether an end-of-line results in an output token
  attr(:eol_as_token, true)

	# Constructor.
  # Initialize language-specific options.
  # [input_text] Optional argument. When present must be a String or a StringScanner.
  #   It is the input to be subjected to lexical analysis.
  # Examples:
  #   -could be created without an argument
  #    AbstractLexer.new()
  #   -could be created with a String argument
  #   AbstractLexer.new("3 + 4")
  #   -could be created with a StringScanner argument
  #   sample_input = "3 + 4"
  #   AbstractLexer.new(StringScanner.new(sample_input))
	def initialize(input_text = nil)
    @engine = LexerEngine.new
		@queue = TokenQueue.new
    engine.input = input_text unless input_text.nil?
  end

public
### TODO #### method to remove
  def scanner()
    raise NotImplementedError
  end

  # Set the input text to be subjected to the lexical analysis.
	# [input_text]	Can be either a String or a StringScanner object.
  # It is the input to subjected to the lexical analysis.
  def input=(input_text)
    engine.input = input_text
  end


	# Purpose: return the next token from the input stream.
	# This is the method to be called by the parser.
	# Return value are of the form expected by Racc:
	# [token_type, a Token object]
	# token_type is either a Symbol or a character that categorises the token recognized from the input text.
	def next_token()
    raise LexicalError.new("No input text was provided.", LexemePosition::at_start) if token_recognition_state == :waiting_for_input

		if queue.empty?
      unless token_recognition_state == :ready
        error_message = "#{__method__} may not be called when state is #{token_recognition_state}"
        raise  LexerSetupError.new(error_message)
      end

      enqueue_next_tokens() # Retrieve token(s) from the input text & enqueue them
    end
    theToken = queue.dequeue()
		return theToken
  end
 
 
	# Return a single character token.
	# Pre-requisite: lexeme attribute contains the single character.
	def scan_single_char()
		result = if metachar?(lexeme)
			# A Meta-character...
			enqueue_token(lexeme.dup)
		else
			enqueue_token(:T_CHARLIT)
		end
		
		return result
	end

  
  # The lexer state is implemented as a combination of two state machines.
  # This helper method returns the names of the current state from both state machines.
  # It is thus a couple of the form:
  # [ name of position in line state, name of token recognition state ]
  def complete_state_name()
    return engine.complete_state_name()
  end


  # Return the name of the current state of the 'token_recognition' STM.
  def token_recognition_state()
    return engine.token_recognition_state()
  end


	# Enqueue the terminating token in the format expected by a RACC-generated parser.
  def enqueue_eos_marker()
		position = build_position(:eos)
		eos_marker =  [false, RaccLexer::Token.new('$', '$', position)]
    queue.enqueue eos_marker
  end


	# Build and enqueue a token with given token type
	# The created token is returned.
	def enqueue_token(aTokenType)
		a_token = build_token(aTokenType)
		queue.enqueue(a_token)

		@token_pos = scanner.pos()	# Update the current position (in case of multiple tokens enqueuing)
		return a_token
	end

  # Required by the actions
  def find_rule(aRuleName) abstract_method
  end


protected
  # Emit an event for the lexing engine.
  # [eventSymbol] the symbolic name of one of the engine's events
  # [arg] additional event arguments
  def trigger_event(eventSymbol, *args)
    engine.send(eventSymbol, *args)
  end

  
  # Initialize the tokenizing state
  def reset()
    raise NotImplementedError
    @lineno = 1
		@line_offset = 0
    @token_pos = 0
  end

  # Purpose: scan the input text for one (or more) token(s).
  # Each found token is then enqueued
  def enqueue_next_tokens()
    case current_state_name(:token_recognition)
      when :ready
        if significant_indentation && (current_state_name(:line_positioning) == :at_line_start)
          scan_indentation()
        end
        loop do
          scanner.skip(noise_pattern)
          if scanner.check(eol_pattern)
            eol_checked()
            next
          end
          if eos?
            eos_detected()
            break
          end

          # Here starts the core tokenizing work...
          # Retrieve the (state-dependent) main/start Lexer rule...
          theRule = find_rule(main_rule_name())

          begin
            # Now apply the rule to the input managed by this Lexer
            theRule.apply_to(self)	# One or more tokens are placed in the queue

            unless current_state_name(:token_recognition) == :recognized
              # Error detected...
              raise InternalLexerError.new("Internal error: Lexer in unexpected state '#{current_state_name(:token_recognition)}'", nil)
            end
          rescue LexerError => exc
            # Enqueue the "exception" as an error token
            error_token = [:error, exc]
            queue.enqueue error_token
          end
        end # loop
      else # Other state ...
        raise LexerSetupError, "Unimplemented handler"
    end
  end

	# Factory method. Builds a LexemePosition object that specifies the position of the current lexeme/token
	# [target] must be one of following values: :eos, :lexeme
	def build_position(target = :lexeme)
		offset = (target == :lexeme)? @token_pos : scanner.pos()
    begin
		linepos = offset - @line_offset # Position relative to start of line
    rescue NoMethodError => exc
      STDERR.puts "@token_pos = #{@token_pos}"
      STDERR.puts "scanner.pos = #{scanner.pos}"
      STDERR.puts "@line_offset = #{@line_offset}"
      raise exc
    end
		position = LexemePosition.new(offset, @lineno, linepos)
		return position
	end


	# Abstract method (must be redefined in a subclass).
	# Purpose: return the regular experssion for the text to be skipped (ignored)
  # such as whitespaces and comments
	def noise_pattern() abstract_method
	end


  # Purpose: return the end of line pattern (as a regular expression).
  # The pattern defines what a end of line (eol) is.
  def eol_pattern()
    return /\r\n?|\n/ # Applicable to *nix, Mac, Windows eol conventions
  end


  # Entry action for done state
  def complete_scan()
    enqueue_eos_marker()
  end
  
  # Retrive the pattern for line indentation
  def indentation_pattern()
    return /^(?: \t)+/
  end
  
  
  # Scan the indentation (if any)
  # If some indentation was found, then it is gobbled and put in the lexeme attrbute.
  # The event indentation_scanned is emitted.
  # Pre-condition/assumption: state of line_positioning == at_line_start
  # Post-condition: state == :after_indentation (if indentation was found), otherwise :at_line_start
  def scan_indentation()
    found_indentation = scanner.scan(indentation_pattern)
    if found_indentation
      self.lexeme = found_indentation
      indentation_scanned()
    end
  end


  # Entry action for at_line_end state.
  # Assumption: eol is at position == scanner.pos()
  def eat_eol()
    if eol_as_token  # if eol is significant in the language...
      position = build_position(:lexeme)
      eol_lexeme = scanner.scan(eol_pattern) # Consume the eol text
      eol_token =  [:T_EOL, RaccLexer::Token.new(eol_lexeme, eol_lexeme, position)]
      queue.unshift eol_token
    else
      scanner.scan(eol_pattern) # Consume the eol text
    end

    @lineno += 1
    @line_offset = scanner.pos()
  end
  
	# Create a token object. RACC requires a token to be a two-elements Array with
	# the first element being the token type (either a Symbol or a character),
	# The second element is the lexeme.
	# Pre-condition: the lexeme attribute contains the complete lexeme (original source text of the token) 
	# Return nil if the current state is :Aborted or :Failed
	def build_token(aTokenType)
		if [:Aborted, :Failed].include? @tokenizing_state
			result = nil
		else
			@tokenizing_state = :Recognized
			if (aTokenType == :EOS) 
				result = eos_marker()
			else
				# TODO: change from couple to triples (token type, value, lexeme). Ultimately add token position as well.
				token_pos = build_position()
				result = [aTokenType,  Token.new(lexeme.dup, lexeme.dup, token_pos)]
			end
			
			lexeme.clear
		end
		
		return result
	end


########################################
# Unvalidated methods
########################################
  # Entry action for the at_line_start state
  def reset_indentation_length()
    puts "reset_indentation_length"
  end


  # Wrapper method for the i_indentation_scanned event.
  def indentation_scanned()
    raise LexerInternalError, "indentation_scanned event may not occur when significant_indentation=false", nil unless significant_indentation
    self.i_indentation_scanned()
  end

  # Compound event.
  # Dispatch method for the state machine expected_char_checked events.
  def expected_char_checked()
    self.expected_char_checked_stm_line()
    self.expected_char_checked_stm_token()
  end




  # Entry action for the after_indentation state
  def emit_indentation()
    puts "Transition action 'emit_indentation'"
  end

end # class

end # module

# End of file