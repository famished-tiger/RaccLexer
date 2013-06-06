# File: JSON_hwlexer.rb
# Handwritten lexer for the JSON data format
# Purpose: should produce same output as a rexical-generated lexer.

require 'strscan'

# Handwritten (HW) lexer for JSON.
# Shares the same API than lexer generated with rexical
class JSONHWLexer
  attr_reader(:scanner)
  attr_reader(:lineno)
  attr_reader(:line_start)
  attr_reader(:filename)
  attr(:state, true)
  
  class ScanError < StandardError ; end  

public
  def scan_setup(src)
    @scanner = StringScanner.new(src)
    @lineno =  1
    @line_start = 0
    @state  = :at_line_start
  end

  def load_file( filename )
    @filename = filename
    open(filename, "r") do |f|
      scan_setup(f.read)
    end
  end
  
  def next_token
    return if @scanner.eos?
    
    # skips empty actions
    until token = _next_token or @scanner.eos?; end
    token
  end
  
private
  def _next_token()
    token = nil
    while((curr_ch = scanner.getch()) or (! scanner.eos?))
      # next if curr_ch == ' ' || curr_ch == "\t" || curr_ch == "\f" # Could be replaced by a regexp
      case curr_ch
        when ' ', '\t', '\f'
          next
          
        when "\n"
          newline_detected
          next
          
        when "\r"
          scanner.getch() if scanner.peek == "\n" # Handle \r\n sequence
          newline_detected
          next
        
        when '{', '}', '[', ']', ',', ':'
          token = [curr_ch, curr_ch]
          
        when 'f', 't', 'n'  # First letter of keywords
          @scanner.pos = scanner.pos - 1 # Simulate putback
          keyw = scanner.scan(/false|true|null/)
          if keyw.nil?
            invalid_keyw = scanner.scan(/\w+/)
            raise ScanError.new("Invalid keyword: #{invalid_keyw}")
          else
            token = [keyw.upcase.to_sym, keyw]
          end
          
        when '"'  # Start string delimiter found
          value = scanner.scan(/([^"\\]|\\.)*/)
          end_delimiter = scanner.getch()
          raise ScanError.new('No closing quotes (") found') if end_delimiter.nil?
          token = [:STRING, value]
          
        when /[-0-9]/ # Start character of number literal found
          @scanner.pos = scanner.pos - 1 # Simulate putback
          value = scanner.scan(/-?[0-9]+(\.[0-9])?([eE][-+]?[0-9])?/)
          token = [:NUMBER, value]
=begin
          # Better: make a difference between integer and real values
          integer_part = scanner.scan(/-?[0-9]+/)
          fract_part = scanner.scan(/\.[0-9]+/)
          exp_part = scanner.scan(/e[-+]?[0-9]+/)
          if fract_part.nil? || exp_art.nil?
            token = [:INTEGER, integer_part.to_i]
          else
            unless fract_part.nil? && exp_art.nil?
              value = integer_part
              value << fract_part unless fract_part.nil?
              value << exp_part unless exp_part.nil?
              token = [:NUMBER, value.to_f]
            end
          end
=end
          
        else # Unknown token
          erroneous = curr_ch.nil? ? '' : curr_ch
          sequel = scanner.scan(/.{1,20}/)
          erroneous << sequel unless sequel.nil?
          raise ScanError.new('Unknown token #{erroneous}')
          
      end #case
      
      break unless token.nil?
    end # while
    
    return token.nil? ? [false, '$'] : token
  end
  
  
  def newline_detected()
    @lineno += 1
    @line_start = scanner.pos()
  end
  
end # class