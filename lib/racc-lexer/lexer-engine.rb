# File: lexer-engine.rb

require 'strscan'	# Use StringScanner for low-level scanning

# The state transition machine (STM) implementation relies
# on the gem edge-state-machine.
# https://github.com/danpersa/edge-state-machine
require "edge-state-machine"

require_relative 'lexer-exceptions'
require_relative 'lexeme-position'

module RaccLexer	# This module is used as a namespace


# Utility class used in saving/restoring the scanning state of a lexer engine.
EngineSnapshot = Struct.new(:scan_position, # The scanning position in the input stream
  :lineno,  # The line number
  :lexeme,  # The buffered copy of the last scanned lexeme
  :noise_pattern, # The regular expression for text to discard
  :indentation_pattern, # The regular expression (if any) for characters recognized as indentation at the start of a line.
  :stm_state  # The state of the STM (State-Transition Machine)
)


=begin rdoc
The LexerEngine class is the workhorse of the RaccLexer library.
It scans over the input text and return the relevant input text fragments
to the higher-level lexer components.
Internally, a LexerEngine contains a StringScanner object that performs
the low-level scanning work. The LexerEngine class is based on the assumption that
each line of text from the input source adheres to the following structure:

  ()->+----------------->+-->+-->+------------>+-->+-->+-- eol -->+-->()
      |                  ^   ^   |             ^   |   |          ^
      v                  |   |   v             |   |   v          |
      +-- indentation -->+   |   +--> noise -->+   |   +-- eos -->+
                             |                     |
                             |                     v
                             +<------ token <------+


A LexerEngine classifies the recognized lexemes from the input text into five categories:
-noise (any text that can be safely ignored by the parser). Typically, "noise" lexemes are:
    comments or whitespace text.
-indentation: typically spaces or tabs at the start of a text line.
-eol: end of line delimiter
-eos: a symbolic representation of the end of the input text.
-token: any other text element that matches a pattern given to the LexerEngine#scan method..


=end
class LexerEngine
  include EdgeStateMachine # Mixin module to implement state machines

	# Link to the shared low-level scanner (behaves as a StringScanner)
  # These are the methods in use: getch, eos?, pos, scan, reset, skip, check
	attr_reader(:scanner)

	# Lexeme being recognized. A lexeme is an extract from the input text that is a recognized as a token of the language.
	attr_reader(:lexeme)

  # The current line number in the input text
	attr_reader(:lineno)

	# The position of the start of current line being scanned.
  # The position is relative to the start of stream.
  # Initially equal to zero then to position just after the last
  # encountered end of line (eol).
	attr_reader(:line_offset)

  
  # A stack of EngineSnapshot objects. Each keeping track of the execution state of the lexer engine.
  attr_reader(:snapshots)


=begin
Coarse-grained state transition machines for a generic lexer.
Two state machines are managed conjointly:
  - line_positioning
  - token_recognition

The line_positioning STM is tracking the current scan position w.r.t. current line of text
(i.e. at the start, at end, in the middle of the current line of text). It also takes into account
indentation.

The token_recognition STM is dedicated to the recognition of tokens.

List of events recognized by the STM:
(these events are notifications of happenings that might potentially change
  the scan position and are related to the text being currently scanned).
eol_checked: the scanner found an end-of-line in the input stream. Position at eol. The eol is not in lexeme.
not_eol_checked: the scanner found any char that is NOT part of end-of-line in the input stream.
eos_detected: the scanner position is at the end of the input stream.
noise_skipped: the scanner found and skipped noise text in the input stream. Position after noise. Noise is not in lexeme.
indentation_scanned: the scanner found an indentation in the input stream. The indentation is in the lexeme.
expected_char_checked: the scanner found a character that could be the begin of a valid token.
unexpected_char_checked: the scanner detected an unexpected character (i.e. a character that cannot be part of some token).
token_recognized: the scanner recognized a valid token in the input stream.
=end
  #######################
  # State machine tracking the current scan position w.r.t. current line of text.
  #######################
  state_machine :line_positioning do
    # Name of the initial state (optional). If absent, the initial state will be the first state defined.
    initial_state :at_line_start

    #######################
    # State definition part
    #######################
    state :at_line_start do
      #enter :reset_indentation_length # Entry action (Not executed in case of initial state)
    end

    state :after_indentation do
      enter :eat_indentation # Entry action
    end

    state :in_line_body

    state :at_line_end do
      enter :eat_eol  # Entry action
    end


    #######################
    # Event definition part
    #######################

    # This event is triggered only when the Lexer recognises the indentation.
    event :indentation_scanned do
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

    # Event: the scanner is ready to scan past an eol
    event :after_eol do
      transition :from => [:at_line_end], :to => :at_line_start, :on_transition => :begin_line
    end


  end # state_machine



  #######################
  # State machine dedicated to the recognition of tokens.
  #######################
  state_machine :token_recognition do
    initial_state :waiting_for_input      # Name of the initial state.

    # The lexer waits for an input text (none was given yet).
    state :waiting_for_input

    # The lexer is ready to find any token in the input text.
    state :ready do
      enter :clear_lexeme # Entry action
    end

    # The lexer tries to match the current lexeme to a token of the language.
    state :tokenizing

    state :recognized

    # End states
    state :done

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
      transition :from => :ready, :to => :recognized
      transition :from => :tokenizing, :to => :recognized
    end


    # Event: a token object was just pushed on the queue
    event :token_enqueued do
       transition :from => :recognized, :to => :ready
    end

  end # state_machine

public
  # Constructor
  def initialize()
    @snapshots = []
    @scanner = nil
  end

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
    @eol_position = 0
    
    input_given() # Trigger an event for one of the state machine
  end


	# Tries to match the text at the current scanning position to the given pattern.
	# If there’s a match, the scanner advances the “scan pointer”, updates the 'lexeme' attribute.
  # Returns a Symbol or nil
  #   - :eos end of input text stream
  #   - :eol end of line
  #   - :indentation blank at start of text line
  #   - :token the current lexeme matched the the given pattern
  #   - nil the pattern did not match the text at the scanning position.
	# Otherwise, the scanner returns nil.
	def scan(aPattern)
    raise LexicalError.new("No input text was provided.", LexemePosition::at_start) if end_state_scanning()

    token_enqueued() if token_recognition_state == :recognized
    if in_state?(:at_line_end, :ready)
      after_eol() # Event
    end 
     
    if in_state?(:at_line_start, nil)
      indentation_found = indentation_pattern.nil? ? nil : scanner.check(indentation_pattern)
      if indentation_found
        indentation_scanned() # STM event
        token_recognized() # STM event
        return :indentation
      end
    end
    scanner.scan(noise_pattern)
    if eos?
      eos_detected() # STM event
      return :eos
    else
      found_eol = scanner.check(eol_pattern)
      unless found_eol.nil?
        eol_checked() # STM event
        return :eol
      end
      
      multiline = is_multiline?(aPattern)    
      result = scanner.scan(aPattern)
      unless result.nil?
        lexeme << result
        if multiline
          lines = lexeme.split(eol_pattern)
          @lineno += lines.size - 1
          @line_offset = scanner.pos() - lines.last.size
        end
        expected_char_checked_stm_line() # STM event
        token_recognized() # STM event
        return :token
      end
    end

		return nil
	end


  ###########
  # State-based methods
  ###########

  # The lexer state is implemented as a combination of two state machines.
  # This helper method returns the names of the current state from both state machines.
  # It is thus a couple of the form:
  # [ name of position in line state, name of token recognition state ]
  def complete_state_name()
    position_in_line_state = current_state_name(:line_positioning)
    token_recognition_state = current_state_name(:token_recognition)

    return [ position_in_line_state, token_recognition_state]
  end

  # Return true if the current state matches the given set of sub-states
  # [ name of position in line state, name of token recognition state ]  
  def in_state?(positionInLineState, tokenRecognitionState)
    match1 = if positionInLineState
      current_state_name(:line_positioning) == positionInLineState
    else
      true
    end
    
    return false unless match1    
    
    match2 = if tokenRecognitionState
      current_state_name(:token_recognition) == tokenRecognitionState
    else
      true
    end
    
    result = if positionInLineState || tokenRecognitionState
      match1 && match2
    else
      false
    end
    
    return result
  end


  # Return the name of the current state of the 'token_recognition' STM.
  def token_recognition_state()
    return current_state_name(:token_recognition)
  end

  # Check whether the token recognition state reached an end state
  def end_state_scanning()
    end_states = [:done, :aborted, :failed]
    return end_states.include? token_recognition_state
  end


	# Return true iff end of input text is reached.
  # This method leaves the state machines unchanged.
	def eos?()
    scanning_state = token_recognition_state()
    return true if  (scanning_state == :done) || (scanning_state == :aborted)

    return scanner.eos?()
	end
  
  # The last returned lexeme was an eol.
  # Prepare the scanner to work on another line.
  def begin_line()
    clear_lexeme()
    @line_offset = scanner.pos()
    @lineno += 1  
  end

  ###########
  # Pattern-based methods
  ###########

  # Purpose: give the regular expression recognizing line separators.
  def eol_pattern()
    return /\r?\n|\r/  # In plain English: \n or \r\n or \r
  end

  
  # Purpose: give the regular expression of input text elements that should
  # be discarded (= not returned to the parser).
  # Noise typically consists of:
  # Comments, whitespace (NOT INCLUDING line separators)
  # Override this method if the language has different comment conventions.
  # TODO: Make it state-dependent
  def noise_pattern()
    # noise pattern = one or more of the following:
    # - Ruby-style line comment: # This is a comment until the end of line
    # - Single line C-style comment: /* This is a comment */
    # - whitespace character: a space, a tab or a form feed
    return /(?:#.*|\/\*.*?\*\/|[ \t\f])+/  # Two comment styles: C comments /* comment */,  # Comment...
  end

  # Return the regular expression that recognizes the characters allowed in a line indentation.
  def indentation_pattern()
    return /(?: |\t)+/
  end

  # Purpose = Make the lexeme text empty.
	def clear_lexeme()
		@lexeme = ''
	end

  # Pre-condition: eol is at current scanning position.
  def eat_eol()
    @lexeme = scanner.scan(eol_pattern)     # Copy eol into the lexeme attribute
    @line_offset = scanner.pos()    
  end

  def eat_indentation()
    @lexeme = scanner.scan(indentation_pattern)     # Copy indentation text into the lexeme attribute
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

	# Read unconditionally the character at current scanning position.
	# Position is incremented.
	# Returns the read character or raise an exception if current position is at eos.
	def next_char()
		ch = scanner.getch()

		if ch.nil?
			eos_detected()	# Emit event
		else
			lexeme << ch
		end

		return ch
	end


  ###########
  # Snapshot-specific methods
  ###########

  # Make a snapshot of the current execution state of the lexer engine
  # and push it on the stack.
  def add_snapshot()
    # Record the current execution state...
    image = EngineSnapshot.new
    image.scan_position = scanner.pos()
    image.lineno = self.lineno
    image.lexeme = self.lexeme
    # image.noise_pattern = self.noise_pattern
    # image.indentation_pattern = self.indentation_pattern
    image.stm_state = { :line_positioning => current_state(:line_positioning),
      :token_recognition => current_state(:token_recognition)
    }

    snapshots << image  # Pushing it...
  end


  # Pop the topmost snapshot from the stack and make its
  # settings the current execution state of the lexer engine.
  def restore_snapshot()
    image = pop_snapshot()
    if image.nil? # Was the stack empty?...
      # TODO: calculate accurate offset in line.
      raise InternalLexerError.new("Snapshot stack is empty.",  LexemePosition::new(scanner.position, lineno, 0))
    end

    scanner.pos = image.scan_position
    @lineno = image.lineno
    @lexeme = image.lexeme
    # self.noise_pattern = image.noise_pattern
    # self.indentation_pattern = image.indentation_pattern =
    set_current_state(image.stm_state[:line_positioning], :line_positioning)
    set_current_state(image.stm_state[:token_recognition], :token_recognition)
  end


  # Remove the topmost snapshot from the stack and
  # return it.
  def pop_snapshot()
    return snapshots.pop()
  end


protected
  # Initialize the tokenizing state
  def reset()
    @lineno = 1
		@line_offset = 0
    @token_pos = 0
  end
  
  # Utility method. Returns true if the given regexp is multiline.
  def is_multiline?(aRegexp)
    return (aRegexp.options & Regexp::MULTILINE) != 0
  end

end # class

end # module

# End of file