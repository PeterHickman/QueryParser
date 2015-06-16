require 'test_helper'

class TC_Boostable < Minitest::Test
  def compare(e, a)
    assert_equal(e.class, a.class)
    assert_equal(e.type, a.type)
    assert_equal(e.data, a.data)
  end

  # Simple terms
  def test_term_default_negative
    t = QueryParser::Term.new('tom')

    b = t.boostable()

    compare(t, b)
  end

  def test_term_negative_is_false
    t = QueryParser::Term.new('tom')

    b = t.boostable(false)

    compare(t, b)
  end

  def test_term_negative_is_true
    t = QueryParser::Term.new('tom')

    b = t.boostable(true)

    assert_equal(NilClass, b.class)
  end

  # Testing some nots
  def test_not_default_negative
    t = QueryParser::Term.new('tom')
    n = QueryParser::Not.new(t)

    b = n.boostable()

    assert_equal(NilClass, b.class)
  end

  def test_not_negative_is_false
    t = QueryParser::Term.new('tom')
    n = QueryParser::Not.new(t)

    b = n.boostable(false)

    assert_equal(NilClass, b.class)
  end

  def test_not_negative_is_true
    t = QueryParser::Term.new('tom')
    n = QueryParser::Not.new(t)

    b = n.boostable(true)

    assert_equal(QueryParser::Term, b.class)
    assert_equal('term', b.type)
    assert_equal('tom', b.data)
  end

  def test_double_not
    t = QueryParser::Term.new('tom')
    n1 = QueryParser::Not.new(t)
    n2 = QueryParser::Not.new(n1)

    b = n2.boostable()

    compare(t, b)
  end

  # Test the sets
  def test_and_with_three_items
    t1 = QueryParser::Term.new('tom')
    t2 = QueryParser::Term.new('dick')
    t3 = QueryParser::Term.new('harry')

    s = QueryParser::And.new
    s.add(t1)
    s.add(t2)
    s.add(t3)

    b = s.boostable()

    assert_equal(Array, b.class)
    assert_equal(3, b.size)

    compare(t1, b[0])
    compare(t2, b[1])
    compare(t3, b[2])
  end

  def test_and_with_a_not
    t1 = QueryParser::Term.new('tom')
    t2 = QueryParser::Term.new('dick')
    t3 = QueryParser::Term.new('harry')

    n = QueryParser::Not.new(t3)

    s = QueryParser::And.new
    s.add(t1)
    s.add(t2)
    s.add(n)

    b = s.boostable()

    assert_equal(Array, b.class)
    assert_equal(2, b.size)

    compare(t1, b[0])
    compare(t2, b[1])
  end

  def test_and_with_a_double_negative
    t1 = QueryParser::Term.new('tom')
    t2 = QueryParser::Term.new('dick')
    t3 = QueryParser::Term.new('harry')

    n1 = QueryParser::Not.new(t2)
    n2 = QueryParser::Not.new(n1)

    s = QueryParser::And.new
    s.add(t1)
    s.add(n2)
    s.add(t3)

    b = s.boostable()

    assert_equal(Array, b.class)
    assert_equal(3, b.size)

    compare(t1, b[0])
    compare(t2, b[1])
    compare(t3, b[2])
  end
end
