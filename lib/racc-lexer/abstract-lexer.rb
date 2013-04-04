# File: abstract-lexer.rb

require "pp"
require 'strscan'	# Use StringScanner for low-level scanning
require "edge-state-machine"  # https://github.com/danpersa/edge-state-machine

require_relative '../abstract-method'
require_relative 'token'
require_relative 'token-queue'

module RaccLexer	# This module is used as a namespace


=begin

List of events:
(the events are notifications of happenings that might potential change the scan position and are related to the text being currently scanned).
eol_checked: the scanner found an end-of-line in the input stream. Position at eol. The eol is not in lexeme.
not_eol_checked: the scanner found any char that is NOT part of end-of-line in the input stream.
eos_detected: the scanner position is at the end of the input stream.
noise_skipped: the scanner found and skipped noise text in the input stream. Position after noise. Noise is not in lexeme.
indentation_scanned: the scanner found an indentation in the input stream. The indentation is in the lexeme.
expected_char_checked: the scanner found a character that could be the begin of a valid token.
unexpected_char_checked: the scanner detected an unexpected character (i.e. a character that cannot be part of some token).
token_recognized: the scanner recognized a valid token in the input stream.
=end


class AbstractLexer
  include AbstractMethod   # Mixin module to mark some methods as abstract
  include EdgeStateMachine # Mixin module to implement state machines

	# Link to the shared low-level scanner (behaves as a StringScanner)
	attr_reader(:scanner)

	# Lexeme being recognized. A lexeme is an extract from the input text that is a recognized as a token of the language.
	attr_reader(:lexeme)

	# A FIFO queue of tokens. Since the lexer can enqueue multiple tokens at once,
	# the queue reduces the need to keep the lexer's state between next_token invokation.
	attr_reader(:queue)

  # A boolean that indicates whether the Lexer should treat indentations as significant or
  # ignored. When indentations are significant, they are treated as particular tokens.
  attr(:significant_indentation, true)

  # A boolean that indicates whether an end-of-line results in an output token
  attr(:eol_as_token, true)

  # The current line number in the input text
	attr_reader(:lineno)

	# The position in the input text just after the last encountered newline.
	attr_reader(:line_offset)

  # State machine dedicated to track the current scan position w.r.t. current line of text.
  state_machine :line_positioning do
    # Name of the initial state (optional). If absent, the initial state will be the first state defined.
    initial_state :at_line_start

    #######################
    # State definition part
    #######################
    state :at_line_start do
      enter :reset_indentation_length # Entry action (Not executed in case of initial state)
    end

    state :after_indentation do
      enter :emit_indentation # Entry action
    end

    state :in_line_body

    state :at_line_end do
      enter :eat_eol  # Entry action
    end


    #######################
    # Event definition part
    #######################

    # This event is triggered only when the Lexer recognises the indentation.
    # The i_ prefix means that this event should be triggred by the method 'indentation_scanned'.
    event :i_indentation_scanned do
      transition :from => :at_line_start, :to => :after_indentation
    end


    # Event: one end of line just found (but not yet consumed)
    event :eol_checked do
      transition :from => [:at_line_start, :after_indentation, :in_line_body, :at_line_end], :to => :at_line_end
    end

    # Event: a character for a potential token just detected
    event :expected_char_checked_stm_line do
      transition :from => [:at_line_start, :after_indentation, :in_line_body], :to => :in_line_body
    end

    # Event: a non-eol token was detected
    event :not_eol_checked do
      transition :from => [:at_line_end], :to => :at_line_start
    end


  end # state_machine



  # State machine dedicated to the recognition of tokens.
  state_machine :token_recognition do
    initial_state :waiting_for_input      # Name of the initial state.

    # The lexer waits for an input text.
    state :waiting_for_input

    # The lexer is ready to find any token in the input text.
    state :ready do
      enter :clear_lexeme # Entry action
    end

    # The lexer tries to match the current lexeme to a token of the language.
    state :tokenizing

    state :recognized

    # End states
    state :done do
      enter :complete_scan
    end

    state :failed # Error state: an unexpected character occurred while Lexer was trying to recognize a lexeme
    state :aborted  # Error state: an unexpected eos occurred while Lexer was trying to recognize a lexeme

    # Event: the text to scan was just provided
    event :input_given do
      transition :from => [:waiting_for_input, :done], :to => :ready, :on_transition => :reset
    end

    # Event: an end of stream just detected
    event :eos_detected do
      transition :from => [:ready, :tokenizing], :to => :done
      transition :from => :tokenizing, :to => :aborted # Premature eos (occurs when candidate token is not yet fully recognized)
    end

    # Event: a character for a potential token just detected
    event :expected_char_checked_stm_token do
      transition :from => [:ready, :tokenizing], :to => :tokenizing
    end


    # Event: a character in lexeme that doesn't fit any token
    event :unexpected_char_checked do
      transition :from => :tokenizing, :to => :failed
    end

    # Event: current lexeme matches a token.
    event :token_recognized do
      transition :from => :tokenizing, :to => :recognized
    end

    # Event: a token object was just pushed on the queue
    event :token_enqueued do
       transition :from => :recognized, :to => :ready
    end

  end # state_machine

	# Constructor.
  # Initialize language-specific options.
  # [input_text] Optional argument. When present must be a String or a StringScanner.
  #   It is the input to be subjected to lexical analysis.
	def initialize(input_text = nil)
    @significant_indentation = false
    @eol_as_token = false
		@queue = TokenQueue.new
    self.input = input_text unless input_text.nil?
  end

public
  # Set the input text to be subjected to the lexical analysis.
	# [input_text]	Can be either a String or a StringScanner object.
  # It is the input to subjected to the lexical analysis.
  def input=(input_text)
    if input_text.kind_of?(StringScanner)
      @scanner = input_text
    else
      if @scanner.nil?
        @scanner =  StringScanner.new(input_text)
      else
        @scanner.string = input_text
      end
    end

    input_given() # Trigger a state change with this event
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

  
	# Read unconditionally the character at current scanning position.
	# Position is incremented.
	# Returns the read character or raise an exception if current position is at eos.
	def next_char()	
		ch = @scanner.getch()
		
		if ch.nil?
			eos_detected()	# Emit event
		else 
			lexeme << ch
		end
		
		return ch
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
    position_in_line_state = current_state_name(:line_positioning)
    token_recognition_state = current_state_name(:token_recognition)

    return [ position_in_line_state, token_recognition_state]
  end


  # Return the name of the current state of the 'token_recognition' STM.
  def token_recognition_state()
    return current_state_name(:token_recognition)
  end


	# Return true iff end of input text is reached
	def eos?()
		return @scanner.eos?()
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
  
	# Tries to match the text at the current position to the pattern.
	# If there’s a match, the scanner advances the “scan pointer” and returns the matched string.
  # The lexeme attributre is updated as well.
  # TODO: ensure that the implementation complies to the state-machine.  
	# Otherwise, the scanner returns nil.
	def scan(aPattern)
		result = @scanner.scan(aPattern)
		lexeme << result unless result.nil?
		
		return result
	end

  # Tell the lower-level scanner to move the current scanning position
  # by the amount of characters in lexeme.
  # TODO: ensure that the implementation complies to the state-machine.
  def undo_scan()
		currPos = scanner.pos() # Retrieve the current scanning position of lower-level scanner.
		delta = lexeme.length
		#reset()	# Side-effect: lexeme is zapped
    clear_lexeme()    
		scanner.reset()	# Force the scanner to be a position zero AND clear matching data.
		scanner.pos= currPos - delta
		@token_pos = scanner.pos
  end


protected
  # Initialize the tokenizing state
  def reset()
    @lineno = 1
		@line_offset = 0
    @token_pos = 0
  end

  # Purpose = Make the lexeme text empty.
	def clear_lexeme()
		@lexeme = ''
	end

  # Purpose: scan the input text for one (or more) token(s).
  # Each found token is then enqueued
  def enqueue_next_tokens()
    case current_state_name(:token_recognition)
      when :ready
        if significant_indentation && (current_state_name(:line_positioning) == :at_line_start)
          found_indentation = scanner.scan(indentation_pattern)
          if found_indentation
            self.lexeme = found_indentation
            indentation_scanned()
          end
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