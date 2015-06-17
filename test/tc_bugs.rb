require 'test_helper'

class TC_Bugs < Minitest::Test
  # Quoted term must be "this and that", no single quotes
  def test_quoted_terms_1
    qp = QueryParser.new('content')
    x = qp.parse('"apple banana"')

    assert_equal('content:"apple banana"', x)
  end

  def test_quoted_terms_2
    qp = QueryParser.new('content')
    x = qp.parse("'apple banana'")

    assert_equal('content:"apple banana"', x)
  end

  # Can we handle embeded quotes?
  def test_embedded_quotes
    qp = QueryParser.new('content')
    x = qp.parse("'apple \"and\" banana'")

    assert_equal('content:"apple and banana"', x)
  end

  # A sub list with only one item. These all came up in the first test session
  def test_sublist_1
    qp = QueryParser.new('content')
    x = qp.parse('apple and (apple)')

    assert_equal('+(+content:apple +content:apple)', x)
  end

  def test_sublist_2
    qp = QueryParser.new('content')
    x = qp.parse('(apple)')

    assert_equal('content:apple', x)
  end

  def test_sublist_3
    qp = QueryParser.new('content')
    x = qp.parse('(apple) and (yoghurt)')

    assert_equal('+(+content:apple +content:yoghurt)', x)
  end

  def test_sublist_4
    qp = QueryParser.new('content')
    x = qp.parse('(apple and yoghurt)')

    assert_equal('+(+content:apple +content:yoghurt)', x)
  end

  def test_sublist_5
    qp = QueryParser.new('content')
    x = qp.parse('(apple yoghurt)')

    assert_equal('+(+content:apple +content:yoghurt)', x)
  end

  def test_sublist_6
    qp = QueryParser.new('content')
    x = qp.parse('apple (yoghurt)')

    assert_equal('+(+content:apple +content:yoghurt)', x)
  end

  # A completely empty sublist, but not an empty query
  def test_empty_sublist
    qp = QueryParser.new('content')

    assert_raises QueryParser::Exceptions::MalformedQuery do
      qp.parse('apple()')
    end
  end

  # Precedence of 'and' and 'or'
  def test_precedence
    qp = QueryParser.new('content')
    x1 = qp.parse('apple and banana or cherry and fig')
    x2 = qp.parse('(apple and banana) or (cherry and fig)')

    assert_equal(x1, x2)
  end

  # These should be flagged as malformed
  def test_malformed_1
    qp = QueryParser.new('content')

    assert_raises QueryParser::Exceptions::MalformedQuery do
      qp.parse('apple or and banana')
    end
  end

  def test_malformed_2
    qp = QueryParser.new('content')

    assert_raises QueryParser::Exceptions::EmptyQuery do
      qp.parse('and and and and')
    end
  end

  def test_malformed_3
    qp = QueryParser.new('content')

    assert_raises QueryParser::Exceptions::MalformedQuery do
      qp.parse('banana not')
    end
  end

  def test_malformed_4
    qp = QueryParser.new('content')

    assert_raises QueryParser::Exceptions::MalformedQuery do
      qp.parse('((banana not))')
    end
  end

  # The effects of punctuation
  def test_punctuation_1
    qp = QueryParser.new('content')

    assert_raises QueryParser::Exceptions::EmptyQuery do
      qp.parse('$%^%^&$%*$%')
    end
  end

  def test_punctuation_2
    qp = QueryParser.new('content')

    assert_raises QueryParser::Exceptions::EmptyQuery do
      qp.parse('$  %^%^   &$% *$%')
    end
  end

  def test_punctuation_3
    qp = QueryParser.new('content')

    x = qp.parse('$  %^%apple^   &$% *$%')
    assert_equal('content:apple', x)
  end

  # Surplus ( )
  def test_surplus_braces_1
    qp = QueryParser.new('content')
    qp.parse('fig ((apple banana cherry))')
  end

  def test_surplus_braces_2
    qp = QueryParser.new('content')
    qp.parse('(apple and (not apple or fig))')
  end

  def test_surplus_braces_3
    qp = QueryParser.new('content')
    qp.parse('(apple and not (not fig and fig and not elephant))')
  end
end
