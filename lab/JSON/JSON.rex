#
# JSON.rex
# lexical definition sample for rex
#
# usage
#  rex  JSON.rex  --stub
#  ruby JSON.rex.rb JSON_sample03.txt
#

class JSONRexLexer

rule

# Whitespaces
  ([\s\n\r]|\r\n)+    # No action

# Separators
  [\[\]\{\}:,]                       { [text, text] }
  
# Keywords
  false                              { [:FALSE, text] }
  true                               { [:TRUE, text]  }
  null                               { [:NULL, text]  }
  
# Literals
  -?[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)? { [:NUMBER, text] }
  "([^\\"]|\\.|)*"                      { [:STRING, text] }
  
end