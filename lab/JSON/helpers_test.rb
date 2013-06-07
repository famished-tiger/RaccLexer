require 'pp'
require 'minitest/autorun'
require_relative 'helpers'


class TestHelpers < MiniTest::Unit::TestCase
  def setup()
    @host = Object.new
    @host.extend(Helpers)
  end

  def test_escape_char()
    assert_equal('a', @host.escape_char('a'))
    assert_equal(' ', @host.escape_char(' '))
    assert_equal('\a', @host.escape_char("\a"))
    assert_equal('\b', @host.escape_char("\b"))
    assert_equal('\e', @host.escape_char("\e"))
    assert_equal('\f', @host.escape_char("\f"))
    assert_equal('\n', @host.escape_char("\n"))
    assert_equal('\r', @host.escape_char("\r"))
    assert_equal('\t', @host.escape_char("\t"))
    assert_equal('\v', @host.escape_char("\v"))
    assert_equal('\x1a', @host.escape_char("\x1a"))
  end  
  
 
  def test_char2lit()
    assert_equal("' '", @host.char2lit(' '))  
    assert_equal('?a', @host.char2lit('a'))
    assert_equal('?\a', @host.char2lit("\a"))
    assert_equal('?\x1a', @host.char2lit("\x1a"))
  end


  def test_str2lit()
    assert_equal("''", @host.str2lit(''))
    assert_equal("'a'", @host.str2lit('a'))
    assert_equal(%q|"\n"|, @host.str2lit("\n"))
    assert_equal("'ab'", @host.str2lit('ab'))
    assert_equal("'\"a\"'", @host.str2lit('"a"'))
    assert_equal("\"'ab'\"", @host.str2lit("'ab'"))
  end
end # class

# End of file