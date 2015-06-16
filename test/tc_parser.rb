require 'test_helper'

class TC_Parser < Minitest::Test
  def test_parse_single_term
    p = QueryParser.new("content")
    x = p.parse("apple")

    assert_equal("content:apple", x)
  end

  def test_parse_and
    p = QueryParser.new("content")
    x = p.parse("apple and banana")

    assert_equal("+(+content:apple +content:banana)", x)
  end

  def test_parse_multiple_terms
    p = QueryParser.new("content")
    x = p.parse("apple banana cherry damson elephant")

    assert_equal("+(+content:apple +content:banana +content:cherry +content:damson +content:elephant)", x)
  end

  def test_parse_or
    p = QueryParser.new("content")
    x = p.parse("(apple banana) OR (cherry damson)")

    assert_equal("+((+content:apple +content:banana) (+content:cherry +content:damson))", x)
  end

  def test_parse_not
    p = QueryParser.new("content")
    x = p.parse('apple not banana')

    assert_equal("+(+content:apple -content:banana)", x)
  end

  def test_parse_not_in_or
    p = QueryParser.new("content")
    x = p.parse('apple not banana or cherry')

    assert_equal("+((+content:apple -content:banana) content:cherry)", x)
  end

  def test_parse_not_or_term
    p = QueryParser.new("content")
    x = p.parse("apple not (banana or cherry)")

    assert_equal("+(+content:apple -(content:banana content:cherry))", x)
  end

  def test_parse_not_and_term
    p = QueryParser.new("content")
    x = p.parse("apple not (banana and cherry)")

    assert_equal("+(+content:apple -(+content:banana +content:cherry))", x)
  end

  def test_parse_not_in_and
    p = QueryParser.new("content")
    x = p.parse("apple banana not cherry damson")

    assert_equal("+(+content:apple +content:banana -content:cherry +content:damson)", x)
  end

  def test_parse_simple_not
    p = QueryParser.new("content")
    x = p.parse("not apple")

    assert_equal("-content:apple", x)
  end

  def test_parse_double_not
    p = QueryParser.new("content")
    x = p.parse("not not apple")

    assert_equal("content:apple", x)
  end

  def test_parse_triple_not
    p = QueryParser.new("content")
    x = p.parse("not not not apple")

    assert_equal("-content:apple", x)
  end

  def test_parse_quadruple_not
    p = QueryParser.new("content")
    x = p.parse("not not not not apple")

    assert_equal("content:apple", x)
  end

  def test_parse_double_not_in_and
    p = QueryParser.new("content")
    x = p.parse("apple not not banana cherry")

    assert_equal("+(+content:apple +content:banana +content:cherry)", x)
  end

  # Test for unbalanced braces
  def test_unbalanced_braces_1
    p = QueryParser.new("content")
    assert_raises QueryParser::Exceptions::UnbalancedBraces do
      p.parse("apple (")
    end
  end

  def test_unbalances_braces_2
    p = QueryParser.new("content")
    assert_raises QueryParser::Exceptions::UnbalancedBraces do
      p.parse("apple )")
    end
  end

  # Test for empty queries
  def test_parse_empty_query_1
    p = QueryParser.new("content")
    assert_raises QueryParser::Exceptions::EmptyQuery do
      p.parse("not")
    end
  end

  def test_parse_empty_query_2
    p = QueryParser.new("content")
    assert_raises QueryParser::Exceptions::EmptyQuery do
      p.parse("")
    end
  end

  def test_parse_empty_query_3
    p = QueryParser.new("content")
    assert_raises QueryParser::Exceptions::EmptyQuery do
      p.parse("()")
    end
  end

  def test_parse_empty_query_4
    p = QueryParser.new("content")
    assert_raises QueryParser::Exceptions::EmptyQuery do
      p.parse("and")
    end
  end

  def test_parse_empty_query_5
    p = QueryParser.new("content")
    assert_raises QueryParser::Exceptions::EmptyQuery do
      p.parse("(or)")
    end
  end

  # Malformed queries
  def test_parse_malformed_1
    p = QueryParser.new("content")
    assert_raises QueryParser::Exceptions::MalformedQuery do
      p.parse("apple or")
    end
  end

  def test_parse_malformed_2
    p = QueryParser.new("content")
    assert_raises QueryParser::Exceptions::MalformedQuery do
      p.parse("or apple or")
    end
  end
end
