# File: non-token-rule.rb

module RaccLexer	# This module is used as a namespace

		
# A non-token rule indicates which parts from the input text is NOT considered as a language token.
# Non-tokens are ignored (they are skipped in the lexical scanning and aren't passed to the parser).
# A non-token rule is basically an aggregate of regular expression patterns.
class NonTokenRule	
	# A Hash with pairs of the form: non-token category => regular expression
	attr_reader(:non_tokens)
	
	# The aggregated regular expression
	attr_reader(:pattern)
	
	# [nonTokens] A Hash with pairs of the form: :nonTokenSymbol => regular expression
	def initialize( nonTokens)
		@non_tokens = nonTokens
		@pattern = init_pattern()
	end
	
private
	# Create the aggregate regular expression
	def init_pattern()
		# Retrieve individual regexp
		allNonTokenPatterns = @non_tokens.values.compact()
		
		# Combine them
		combination = Regexp.union(*allNonTokenPatterns)
		
		# Make it non-capturing ...for performance reason
		non_capturing = Regexp.new('(?:' + combination.source + ')')
		
		return non_capturing
	end
end # class

end # module

# End of file