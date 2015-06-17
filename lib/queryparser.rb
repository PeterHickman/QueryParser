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
    d = [d] if d.class != Array

    f = process_not(d)
    g = process_and_or(f, 'and')
    h = process_and_or(g, 'or')

    # Wrap everything in an and
    s = QueryParser::And.new
    s.add(h)

    t = reduce(s)

    b = QueryParser::Or.new
    b.add(t.boostable)

    a = []
    x = t.lucene(@field, @similarity)
    x = "+#{x}" if x[0].chr == '('
    a << x

    @boosts.each_pair do |k, v|
      x = [@similarity, v].join('')
      a << b.lucene(k, x)
    end

    a.join(' ')
  end

  private

  # Split the string into tokens based on whitespace unless it is
  # enclosed in ' or ". Initially we classify everything as either
  # a term or quoted.
  #
  # The input is a text string and the output a flat list of terms
  def tokenise(text)
    r = []

    delimiter = ''
    token = ''

    text.split('').each do |char|
      if delimiter == ''
        if char == '"' || char == "'"
          token = remove_punctuation(token)
          r << QueryParser::Term.new(token) if token != ''
          delimiter = char.dup
          token = char.dup
        elsif char == ' '
          token = remove_punctuation(token)
          r << QueryParser::Term.new(token) if token != ''
          token = ''
        else
          token << char.dup
        end
      elsif delimiter == char
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

    r
  end

  # All our terms will be a-Z0-9 and ( and ). The rest is lost
  def remove_punctuation(a)
    return a if a == ''

    first = a[0].chr
    last = a[-1].chr

    quoted = false
    quoted = true if first == last if first == '"' || first == "'"

    b = a.gsub(/[^[:alnum:]()]/, ' ')
    c = b.gsub(/\s+/, ' ').strip

    if quoted
      return ['"', c, '"'].join('')
    else
      return c
    end
  end

  # If any terms have '(' or ')' in them then expand them up and tokenise
  #
  # The input is a list of terms, the output is a (possibly longer) list of terms
  def expand(a)
    r = []

    a.each do |i|
      if i.type == 'term' && (i.data.index('(') || i.data.index(')'))
        x = i.data.gsub('(', ' ( ').gsub(')', ' ) ')
        r << tokenise(x)
      else
        r << i
      end
    end

    r.flatten
  end

  # Create nested lists around the 'open' and 'close' ops
  #
  # The input is a list of terms, the output is a list of terms and lists of the same
  def maketree(a)
    r = []

    while x = a.shift
      case x.type
      when 'open'
        y = maketree(a)
        if y.size == 1
          r << y[0]
        elsif y.size > 1
          r << y
        end
      when 'close'
        return r
      else
        r << x
      end
    end

    if r.size == 1
      return r[0]
    else
      return r
    end
  end

  # Add the implicit 'and' after a term that is not itself an op
  #
  # The input is a list of terms and lists of same, the output is a (possibly longer) list of terms
  def add_implicit_and(a)
    r = []

    a.each do |i|
      if r.size > 0
        if previous_type(r.last)
          r << QueryParser::Term.new('and') if current_type(i)
        else
          fail QueryParser::Exceptions::MalformedQuery unless current_type(i)
        end
      end

      r << i
    end

    fail QueryParser::Exceptions::MalformedQuery if r.last.type == 'op'

    r
  end

  # All these behave the same for adding an 'and'
  def previous_type(i)
    (i.type == 'term' || i.type == 'close')
  end

  def current_type(i)
    (i.type == 'term' || i.type == 'open' || i.data == 'not')
  end

  # The not picks up the term to it's right
  #
  # The 'Not' op terms in the list are converted into Not objects
  def process_not(a)
    r = []

    # So we can handle a 'not not not apple' and the like
    b = a.reverse

    b.each do |i|
      i = process_not(i) if i.class == Array

      if i.class == QueryParser::Term && i.type == 'op' && i.data == 'not'
        if r.size == 0
          fail QueryParser::Exceptions::MalformedQuery
        else
          x = QueryParser::Not.new(r.pop)
          r << x
        end
      else
        r << i
      end
    end

    r.reverse
  end

  # Find all the 'and' and 'or' op terms and convert them into And and Or objects
  def process_and_or(a, type)
    # make sure that it is in an array
    a = [a] if a.class != Array

    r = []

    has_op = false
    s = nil

    a.each do |i|
      # First recurse into each element
      if i.class == Array
        x = process_and_or(i, type)
        if x.class == Array && x.size == 1
          i = x.first
        else
          i = x
        end
      elsif i.class == QueryParser::Not
        x = process_and_or(i.contents, type)
        x = x.first if x.class == Array && x.size == 1
        i = QueryParser::Not.new(x)
      elsif i.class == QueryParser::And
        x = process_and_or(i.contents, type)
        i = QueryParser::And.new
        i.add(x)
      elsif i.class == QueryParser::Or
        x = process_and_or(i.contents, type)
        i = QueryParser::Or.new
        i.add(x)
      end

      if has_op == true
        s.add(i)
        r << s
        s = nil
        has_op = false
      elsif i.class == QueryParser::Term && i.type == 'op' && i.data == type
        has_op = true
        if i.data == 'and'
          s = QueryParser::And.new
        else
          s = QueryParser::Or.new
        end

        if r.size == 0
          fail QueryParser::Exceptions::MalformedQuery
        else
          s.add(r.pop)
        end
      else
        r << i
      end
    end

    if r.size == 1
      return r[0]
    else
      return r
    end
  end

  # Reduce the sets down
  def reduce(a)
    process = true

    while process
      a = a.reduce
      process = false if a.reduced? == false
    end

    a
  end

  # Check that the "(" and ")" are balanced
  def check_braces(a)
    counter = 0

    a.each do |i|
      if i.type == 'open'
        counter += 1
      elsif i.type == 'close'
        counter -= 1
        fail QueryParser::Exceptions::UnbalancedBraces if counter < 0
      end
    end

    fail QueryParser::Exceptions::UnbalancedBraces if counter != 0
  end

  def has_content(a)
    counter = 0

    a.each do |i|
      counter += 1 if i.type == 'term'
    end

    fail QueryParser::Exceptions::EmptyQuery if counter == 0
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

    if @data.nil?
      @data = ''
    else
      case @data.downcase
        when '('
          @type = 'open'
        when ')'
          @type = 'close'
        when 'and', 'or', 'not'
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
    self
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
    if negative == true
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
    @data = []
    @was_reduced = false
  end

  # Add a list of +terms+, +nots+ and other +sets+
  # to the list of things that are in this part
  # of the query.
  #
  # Can handle a list of items or just a single one.
  def add(*data)
    data.each do |i|
      if i.class == Array
        i.each { |j| add(j) }
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
    r = []
    @data.each { |i| r << i.inspect }
    "<#{inspect_class} #{r.join(' ')}>"
  end

  # Convert a set into string usable in a Lucene query
  # with an optional similarity that needs to be passed
  # to the Terms
  def lucene(field, similarity = nil)
    r = []
    @data.each do |i|
      x = ''
      x = '+' if self.class == QueryParser::And && i.class != QueryParser::Not
      x << i.lucene(field, similarity)
      r << x
    end

    if r.size == 1
      "#{r[0]}"
    else
      "(#{r.join(' ')})"
    end
  end

  # A Set contained within a Set should fold the contents of the inner set
  # into itself. Otherwise reduce the contents of the Set individually and
  # set the flag if the contents reduced
  def reduce
    r = []
    @was_reduced = false

    @data.each do |i|
      if self.class == i.class
        @was_reduced = true
        i.contents.each do |c|
          r << c.reduce
        end
      else
        x = i.reduce
        @was_reduced = true if x.reduced?
        r << x
      end
    end

    if r.size == 1
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
    r = []

    @data.each do |i|
      x = i.boostable(negative)
      r << x unless x.nil?
    end

    r.flatten
  end
end

# A subclass just to distinguish the +and+ from the +or+
class QueryParser::And < QueryParser::Set
  def inspect_class
    'AND'
  end
end

# A subclass just to distinguish the +and+ from the +or+
class QueryParser::Or < QueryParser::Set
  def inspect_class
    'OR'
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
    if @data.class == QueryParser::Not
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
