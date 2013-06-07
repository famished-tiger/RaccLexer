# File: helpers.rb

module Helpers

  # Assumption: characters to escape have a codepoint lower than space char.
  def escape_char(aChar)
    charCode = aChar.ord
    text = if charCode >= ' '.ord
      aChar
    else
      case aChar
      when "\a" then '\a'
      when "\b" then '\b'
      when "\e" then '\e'
      when "\f" then '\f'
      when "\n" then '\n'
      when "\r" then '\r'
      when "\t" then '\t'
      when "\v" then '\v'
      else
        # Emit hexadecimal escape sequence
        '\x' + charCode.to_s(16)
      end
    end

    return text
  end

  #Return the Ruby text representation of the given character.
  # Examples:
  # char2lit('a') # => ?a
  # char2lit(' ') # => ' '
  # char2lit("\n")# => ?\n
  def char2lit(aChar)
    text = if aChar == ' '
      "' '"
    else
      "?#{escape_char(aChar)}"
    end

    return text
  end


  def str2lit(aStr)
    quote_found = false
    escape_needed = false
    chars = aStr.chars.to_a

    chars.map! do |ch|
      lit = escape_char(ch)
      if lit.size == 1
        quote_found = true if lit == "'"
      else
        escape_needed = true
      end
      lit
    end

    delimiter = (quote_found || escape_needed)? '"' : "'"
    if delimiter == '"'
      # Escape the (") and (\)
      chars.map! do |ch| 
        case ch
        when ?" then '\"'
        when ?\ then '\\'
        else
          ch
        end
      end
    end

    return delimiter + chars.join('') + delimiter
  end

end # module

# End of file