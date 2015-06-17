require 'test_helper'

class TC_Terms < Minitest::Test
  # Create an ordinary term of type 'term'
  def test_create_plain_term
    t = QueryParser::Term.new('fred')
    assert_equal('term', t.type)
    assert_equal('fred', t.data)
    assert_equal('term:fred', t.inspect)
  end

  # A 'term' with '(' becomes an 'open'
  def test_create_open
    t = QueryParser::Term.new('(')
    assert_equal('open', t.type)
    assert_equal('(', t.data)
    assert_equal('open:(', t.inspect)
  end

  # A 'term' with ')' becomes a 'close'
  def test_create_close
    t = QueryParser::Term.new(')')
    assert_equal('close', t.type)
    assert_equal(')', t.data)
    assert_equal('close:)', t.inspect)
  end

  # Recognise the 'and' operator
  def test_create_and
    t = QueryParser::Term.new('and')
    assert_equal('op', t.type)
    assert_equal('and', t.data)
    assert_equal('op:and', t.inspect)
  end

  # Check that the case in not important
  def test_create_and_capital
    t = QueryParser::Term.new('AND')
    assert_equal('op', t.type)
    assert_equal('and', t.data)
    assert_equal('op:and', t.inspect)
  end

  # Recognise the 'or' operator
  def test_create_or
    t = QueryParser::Term.new('or')
    assert_equal('op', t.type)
    assert_equal('or', t.data)
    assert_equal('op:or', t.inspect)
  end

  # Recognise the 'not' operator
  def test_create_not
    t = QueryParser::Term.new('not')
    assert_equal('op', t.type)
    assert_equal('not', t.data)
    assert_equal('op:not', t.inspect)
  end

  # A non 'term' should not have special processing
  def test_create_other
    t = QueryParser::Term.new('"and"')
    assert_equal('term', t.type)
    assert_equal('"and"', t.data)
    assert_equal('term:"and"', t.inspect)
  end

  # Check that the case in not important
  def test_create_other_capital
    t = QueryParser::Term.new('")"')
    assert_equal('term', t.type)
    assert_equal('")"', t.data)
    assert_equal('term:")"', t.inspect)
  end

  # The case of the data should be unchanged
  def test_create_capital_data
    t = QueryParser::Term.new('FreD')
    assert_equal('FreD', t.data)
    assert_equal('term:FreD', t.inspect)
  end

  # Can create with empty string as data
  def test_create_empty_string
    t = QueryParser::Term.new('')
    assert_equal('', t.data)
    assert_equal('term:', t.inspect)
  end

  # Can create non 'term' with a nil as data
  def test_create_other_with_nil
    t = QueryParser::Term.new(nil)
    assert_equal('', t.data)
    assert_equal('term:', t.inspect)
  end
end
