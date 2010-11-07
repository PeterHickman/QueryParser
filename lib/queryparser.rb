# Takes a query in plain english and turns it into a string 
# suitable to passing to Lucene or Solr.
#
# Assuming a Lucene / Solr database that has the body of the
# data in the +content+ field with the entry heading in a
# +title+ field, sub headings in a +subheading+ field
#
#  p = QueryParser.new('content')
#  l = p->parse("apple")            
#    => "content:apple"
#
#  l = p->parse("apple and banana")          
#    => "+(+content:apple +content:banana)"
#
#  l = p.parse('apple not banana or cherry') 
#    => "+((+content:apple -content:banana) content:cherry)"
#
# Here we boost the score of those queries that also match the
# title field of the document
#
#  p = QueryParser.new("content", nil, 'title' => '^10')
#  l = p.parse("apple")
#    => "content:apple title:apple^10"
#
# Now with an extra boosting for subheadings
#
#  p = QueryParser.new("content", nil, 'title' => '^10', 'subheading' => '^5')
#  l = p.parse("apple")
#    => "content:apple title:apple^10 subheading:apple^5"
#
# We can also change the similarity of the match. In Lucene terms
# a similarity of 1.0 will mean that 'banana' will only match 'banana'.
# However a similarity of 0.6 (entered as ~0.6) will allow 'banana' to 
# match 'canada' which is only two letters different. The default similarity
# in Lucene is 0.6 (if I remember correctly).
#
#  p = QueryParser.new("content", '~0.6', 'title' => '^10')
#  l = p.parse("apple not banana")
#    => "+(+content:apple~0.6 -content:banana~0.6) title:apple~0.6^10"

class QueryParser
  VERSION = '1.0.1'

  def initialize(field, similarity = nil, boosts = {})
    @field = field
    @similarity = similarity
    @boosts = boosts
  end

  # Takes a plain english query and converts it into a string
  # that can be fed into Lucene or Solr. It will apply the 
  # similarity and boostings set in the constructor.  
  def parse(text)
    a = tokenise(text)
    b = expand(a)
    check_braces(b)
    has_content(b)

    c = add_implicit_and(b)

    d = maketree(c)
    if d.class != Array then
      d = [d]
    end

    f = process_not(d)
    g = process_and_or(f, 'and')
    h = process_and_or(g, 'or')

    # Wrap everything in an and
    s = QueryParser::And.new
    s.add(h)

    t = reduce(s)

    b = QueryParser::Or.new
    b.add(t.boostable())

    a = Array.new
    x = t.lucene(@field, @similarity)
    if x[0].chr == '(' then
      x = "+#{x}"
    end
    a << x
      
    @boosts.each_pair do |k, v|
      x = [@similarity, v].join('')
      a << b.lucene(k,x)
    end

    return a.join(' ')
  end

  private

  # Split the string into tokens based on whitespace unless it is 
  # enclosed in ' or ". Initially we classify everything as either
  # a term or quoted.
  #
  # The input is a text string and the output a flat list of terms
  def tokenise(text)
    r = Array.new()

    delimiter = ''
    token = ''

    text.split("").each do |char|
      if delimiter == '' then
        if char == '"' or char == "'" then
          token = remove_punctuation(token)
          r << QueryParser::Term.new(token) if token != ''
          delimiter = char.dup
          token = char.dup
        elsif char == " " then
          token = remove_punctuation(token)
          r << QueryParser::Term.new(token) if token != ''
          token = ''
        else
          token << char.dup
        end
      elsif delimiter == char then
        token << char.dup
        token = remove_punctuation(token)
        r << QueryParser::Term.new(token) if token != ''
        token = ''
        delimiter = ''
      else
        token << char.dup
      end
    end

    token = remove_punctuation(token)
    r << QueryParser::Term.new(token) if token != ''

    return r
  end

  # All our terms will be a-Z0-9 and ( and ). The rest is lost
  def remove_punctuation(a)
    if a == '' then
      return a
    end
    
    first = a[0].chr
    last = a[-1].chr

    quoted = false
    if first == '"' or first == "'" then
      if first == last then
        quoted = true
      end
    end

    b = a.gsub(/[^[:alnum:]()]/,' ')
    c = b.gsub(/\s+/, ' ').strip

    if quoted then
      return ['"', c, '"'].join('')
    else
      return c
    end
  end

  # If any terms have '(' or ')' in them then expand them up and tokenise
  #
  # The input is a list of terms, the output is a (possibly longer) list of terms
  def expand(a)
    r = Array.new

    a.each do |i|
      if i.type == 'term' and (i.data.index("(") or i.data.index(")")) then
        x = i.data.gsub("(", " ( ").gsub(")", " ) ")
        r << tokenise(x)
      else
        r << i
      end
    end

    return r.flatten
  end

  # Create nested lists around the 'open' and 'close' ops
  #
  # The input is a list of terms, the output is a list of terms and lists of the same
  def maketree(a)
    r = Array.new

    while x = a.shift do
      case x.type
      when "open"
        y = maketree(a)
        if y.size == 1 then
          r << y[0]
        elsif y.size > 1 then
          r << y
        end
      when "close"
        return r
      else
        r << x
      end
    end

    if r.size == 1 then
      return r[0]
    else
      return r
    end
  end

  # Add the implicit 'and' after a term that is not itself an op
  #
  # The input is a list of terms and lists of same, the output is a (possibly longer) list of terms
  def add_implicit_and(a)
    r = Array.new

    a.each do |i|
      if r.size > 0 then
        if previous_type(r.last) then
          if current_type(i) then
            r << QueryParser::Term.new('and')
          end
        else
          if not current_type(i) then
            raise QueryParser::Exceptions::MalformedQuery
          end
        end
      end

      r << i
    end

    if r.last.type == 'op' then
      raise QueryParser::Exceptions::MalformedQuery
    end

    return r
  end

  # All these behave the same for adding an 'and'
  def previous_type(i)
    return (i.type == 'term' or i.type == 'close')
  end
  
  def current_type(i)
    return (i.type == 'term' or i.type == 'open' or i.data == 'not')
  end

  # The not picks up the term to it's right
  #
  # The 'Not' op terms in the list are converted into Not objects
  def process_not(a)
    r = Array.new
    
    # So we can handle a 'not not not apple' and the like
    b = a.reverse

    b.each do |i|
      if i.class == Array then
        i = process_not(i)
      end
      
      if i.class == QueryParser::Term and i.type == 'op' and i.data == 'not' then
        if r.size == 0 then
          raise QueryParser::Exceptions::MalformedQuery
        else
          x = QueryParser::Not.new(r.pop)
          r << x
        end
      else
        r << i
      end
    end
    
    return r.reverse
  end
  
  # Find all the 'and' and 'or' op terms and convert them into And and Or objects
  def process_and_or(a, type)
    # make sure that it is in an array
    if a.class != Array then
      a = [a]
    end

    r = Array.new
    
    has_op = false
    s = nil

    a.each do |i|
      # First recurse into each element
      if i.class == Array then
        x = process_and_or(i, type)
        if x.class == Array and x.size == 1 then
          i = x.first
        else
          i = x
        end
      elsif i.class == QueryParser::Not then
        x = process_and_or(i.contents, type)
        if x.class == Array and x.size == 1 then
          x = x.first
        end
        i = QueryParser::Not.new(x)
      elsif i.class == QueryParser::And then
        x = process_and_or(i.contents, type)
        i = QueryParser::And.new()
        i.add(x)
      elsif i.class == QueryParser::Or then
        x = process_and_or(i.contents, type)
        i = QueryParser::Or.new()
        i.add(x)
      end
      
      if has_op == true then
        s.add(i)
        r << s
        s = nil
        has_op = false
      elsif i.class == QueryParser::Term and i.type == 'op' and i.data == type then
        has_op = true
        if i.data == 'and' then
          s = QueryParser::And.new
        else
          s = QueryParser::Or.new
        end
        
        if r.size == 0 then
          raise QueryParser::Exceptions::MalformedQuery
        else
          s.add(r.pop)
        end
      else
        r << i
      end
    end
  
    if r.size == 1 then
      return r[0]
    else
      return r
    end
  end

  # Reduce the sets down
  def reduce(a)
    process = true

    while process do
      a = a.reduce
      if a.reduced? == false then
        process = false
      end
    end
    
    return a
  end

  # Check that the "(" and ")" are balanced
  def check_braces(a)
    counter = 0
    
    a.each do |i|
      if i.type == 'open' then
        counter += 1
      elsif i.type == 'close' then
        counter -= 1
        if counter < 0 then
          raise QueryParser::Exceptions::UnbalancedBraces
        end
      end
    end
    
    if counter != 0 then
      raise QueryParser::Exceptions::UnbalancedBraces
    end
  end

  def has_content(a)
    counter = 0
    
    a.each do |i|
      if i.type == 'term' then
        counter += 1
      end
    end
    
    if counter == 0 then
      raise QueryParser::Exceptions::EmptyQuery
    end
  end
end

# The custom exceptions that may be thrown if there is some 
# problem with the query.
module QueryParser::Exceptions
  # This exception will be thrown if the query is generally 
  # malformed such as <tt>"apple and and banana"</tt> (too many
  # <tt>and</tt>s), <tt>"apple not"</tt> (no term after the +not+)
  # or <tt>"and apple"</tt> (no term before the +and+) and the like
	class MalformedQuery < Exception
	end

  # This exception will be thrown if the query contains 
  # unbalanaced braces
	class UnbalancedBraces < Exception
	end

  # This exception will be thrown if the supplied query string is
  # empty after removing the +and+, +or+, +not+, ( and )
	class EmptyQuery < Exception
	end
end

# A basic search term. The input query is tokenised into
# terms which then cat manipulated to create the query tree.
#
# Generally you should not need to handle this class unless
# you are changing the parser works.
class QueryParser::Term
  # Takes the token from the user's query and classify it:
  #
  # open:: The opening ( used to indicate the start of a parentisised part of the query.
  # close:: The closing ) used to indicate the end of a parentisised part of the query.
  # and:: The term indicating conjunction
  # or:: The term indicating disjunction
  # not:: The term indicating negation
  # term:: None of the above. A term to find.
  def initialize(data)
    @type = 'term'
    @data = data
    @was_reduced = false

    if @data == nil then
      @data = ''
    else
      case @data.downcase
        when "("
          @type = "open"
        when ")"
          @type = "close"
        when "and", "or", "not"
          @type = 'op'
          @data = @data.downcase
      end
    end
  end
  
  attr_reader :type, :data

  # Display the Term, useful for debugging and testing 
  # the Term class in isolation
  def inspect
    "#{@type}:#{@data}"
  end

  # Convert a term into string usable in a Lucene query
  # with an optional similarity
  def lucene(field, suffix = nil)
    "#{field}:#{@data}#{suffix}"
  end

  # Even though a term cannot, itself, be reduced the
  # process will call this method on everything that
  # is in the query. So we need to have this.
  def reduce
    @was_reduced = false
    return self
  end

  # Return true if the previous call to #reduce did
  # actually reduce the term. Again this is a method 
  # universal to all parts of the query and so we 
  # have to have it. But see #set_reduced to see why
  # it can actually return true.
  def reduced?
    @was_reduced
  end

  # If the term was the only member of an +and+, +or+ or
  # double (or any multiple of two) +not+ then it will replace
  # the +and+, +or+ or +not+ in the query and therefore 
  # the original term has reduced and this, the replacement
  # term, needs to indicate that fact. This allows us to
  # flag that.  
  def set_reduced
    @was_reduced = true
  end

  # The query can be traversed to return the terms
  # that are considered *boostable*. In the following
  # +apple+ will be considered positive and returned
  # but +banana+ will not:
  #
  #   apple not banana
  #
  # Terms that are boostable can be used to improve
  # the documents relavance / position in the results list.
  def boostable(negative = false)
    if negative == true then
      return nil
    else
      return self
    end
  end
end

# The base class for the +and+ and +or+ sets.
#
# Generally you should not need to handle this class unless
# you are changing the parser works.
class QueryParser::Set
  def initialize
    @data = Array.new
    @was_reduced = false
  end

  # Add a list of +terms+, +nots+ and other +sets+
  # to the list of things that are in this part
  # of the query.
  #
  # Can handle a list of items or just a single one.  
  def add(*data)
    data.each do |i|
      if i.class == Array then
        i.each {|j| add(j)}
      else
        @data << i
      end
    end
  end

  # Returns all the data held by this set
  def contents
    @data
  end

  # Display the set, useful for debugging and testing 
  def inspect
    r = Array.new
    @data.each {|i|r << i.inspect}
    "<#{self.inspect_class} #{r.join(' ')}>"
  end

  # Convert a set into string usable in a Lucene query
  # with an optional similarity that needs to be passed
  # to the Terms  
  def lucene(field, similarity = nil)
    r = Array.new
    @data.each do |i|
      x = ''
      if self.class == QueryParser::And and i.class != QueryParser::Not then
        x = '+'
      end
      x << i.lucene(field, similarity)
      r << x
    end

    if r.size == 1 then
      "#{r[0]}"
    else
      "(#{r.join(' ')})"
    end
  end

  # A Set contained within a Set should fold the contents of the inner set
  # into itself. Otherwise reduce the contents of the Set individually and 
  # set the flag if the contents reduced
  def reduce
    r = Array.new
    @was_reduced = false

    @data.each do |i|
      if self.class == i.class then
        @was_reduced = true
        i.contents.each do |c|
          r << c.reduce
        end
      else
        x = i.reduce
        if x.reduced? then
          @was_reduced = true
        end
        r << x
      end
    end

    if r.size == 1 then
      @was_reduced = true
      r[0].set_reduced
      return r.first
    else
      @data = r
      return self
    end
  end

  # Did calling #reduce on this set actually reduce it
  def reduced?
    @was_reduced
  end

  # Force the reduced flag to true
  def set_reduced
    @was_reduced = true
  end

  # Return all the boostable terms that are held
  # in the set. Thus for
  #
  #  tom and dick and harry
  #
  # The terms +tom+, +dick+ and +harry+ are all considered
  # boostable. However in
  #
  #  tom and dick and not harry
  #
  # Only the terms +tom+ and +dick+ are considered boostable
  def boostable(negative = false)
    r = Array.new
    
    @data.each do |i|
      x = i.boostable(negative)
      if x != nil then
        r << x
      end
    end
    
    return r.flatten
  end
end

# A subclass just to distinguish the +and+ from the +or+
class QueryParser::And < QueryParser::Set
	def inspect_class
		"AND"
	end
end

# A subclass just to distinguish the +and+ from the +or+
class QueryParser::Or < QueryParser::Set
	def inspect_class
		"OR"
	end
end

# Something to handle the +not+ term in a query
#
# Generally you should not need to handle this class unless
# you are changing the parser works.
class QueryParser::Not
  # +not+ handles a single term and so it is added in
  # initialisation rather than with an add method.
  def initialize(data)
    @data = data
    @was_reduced = false
  end

  # Returns the data held by the +not+  
  def contents
    @data
  end

  # Display the +not+, useful for debugging
  def inspect
    "<NOT #{@data.inspect}>"
  end
  
  # Convert a +not+ into string usable in a Lucene query
  # passing the similarity on to the term contained by
  # the +not+
  def lucene(field, similarity = nil)
    "-#{@data.lucene(field, similarity)}"
  end

  # Double negatives should be eliminated otherwise
  def reduce
    if @data.class == QueryParser::Not then
      @was_reduced = true
      x = @data.contents.reduce
      x.set_reduced
      return x
    else
      @data = @data.reduce
      @was_reduced = @data.reduced?
      return self
    end
  end

  # Were the contents reduced?  
  def reduced?
    @was_reduced
  end

  # Sets the reduced flag to true  
  def set_reduced
    @was_reduced = true
  end

  # Return all the boostable terms that are held
  # in the +not+. Thus for
  #
  #  tom and dick and harry
  #
  # The terms +tom+, +dick+ and +harry+ are all considered
  # boostable. However in
  #
  #  tom and dick and not harry
  #
  # Only the terms +tom+ and +dick+ are considered boostable
  def boostable(negative = false)
    @data.boostable(!negative)
  end
end
