require 'test_helper'

class TC_Reduce < Minitest::Test
  def test_term
    t1 = QueryParser::Term.new('fred')
    t2 = t1.reduce

    assert_equal(t1.class, t2.class)
    assert_equal(t1.type, t2.type)
    assert_equal(t1.data, t2.data)
    assert_equal(false, t2.reduced?)
  end

  def test_and_one_content
    t = QueryParser::Term.new('fred')

    a1 = QueryParser::And.new()
    a1.add(t)

    a2 = a1.reduce

    assert_equal(t.class, a2.class)
    assert_equal(t.type, a2.type)
    assert_equal(t.data, a2.data)
    assert_equal(true, a2.reduced?)
  end

  def test_and_two_content
    t1 = QueryParser::Term.new('fred')
    t2 = QueryParser::Term.new('other')

    a1 = QueryParser::Or.new()
    a1.add(t1)
    a1.add(t2)

    a2 = a1.reduce

    assert_equal(a1.class, a2.class)
    assert_equal(a1.contents.size, a2.contents.size)
    assert_equal(false, a2.reduced?)

    assert_equal(a2.contents[0].class, t1.class)
    assert_equal(a2.contents[0].type, t1.type)
    assert_equal(a2.contents[0].data, t1.data)

    assert_equal(a2.contents[1].class, t2.class)
    assert_equal(a2.contents[1].type, t2.type)
    assert_equal(a2.contents[1].data, t2.data)
  end

  def test_and_containing_and
    t1 = QueryParser::Term.new('first')
    t2 = QueryParser::Term.new('second')
    t3 = QueryParser::Term.new('third')

    a1 = QueryParser::And.new()
    a1.add(t1)
    a1.add(t2)

    a2 = QueryParser::And.new()
    a2.add(a1)
    a2.add(t3)

    a3 = a2.reduce

    assert_equal(true, a3.reduced?)
    assert_equal(3, a3.contents.size)

    assert_equal(a3.contents[0].class, t1.class)
    assert_equal(a3.contents[0].type, t1.type)
    assert_equal(a3.contents[0].data, t1.data)

    assert_equal(a3.contents[1].class, t2.class)
    assert_equal(a3.contents[1].type, t2.type)
    assert_equal(a3.contents[1].data, t2.data)

    assert_equal(a3.contents[2].class, t3.class)
    assert_equal(a3.contents[2].type, t3.type)
    assert_equal(a3.contents[2].data, t3.data)
  end

  def test_and_containing_or
    t1 = QueryParser::Term.new('first')
    t2 = QueryParser::Term.new('second')
    t3 = QueryParser::Term.new('third')

    o = QueryParser::Or.new()
    o.add(t1)
    o.add(t2)

    a1 = QueryParser::And.new()
    a1.add(o)
    a1.add(t3)

    a2 = a1.reduce

    assert_equal(false, a2.reduced?)
    assert_equal(a1.class, a2.class)
    assert_equal(a1.contents.size, a2.contents.size)
  end

  def test_single_not
    t = QueryParser::Term.new('fred')

    n1 = QueryParser::Not.new(t)

    n2 = n1.reduce

    assert_equal(false, n2.reduced?)
    assert_equal(n1.class, n2.class)
    assert_equal(t.class, n2.contents.class)
    assert_equal(t.type, n2.contents.type)
    assert_equal(t.data, n2.contents.data)
  end

  def test_double_not
    t = QueryParser::Term.new('fred')

    n1 = QueryParser::Not.new(t)
    n2 = QueryParser::Not.new(n1)

    n3 = n2.reduce

    assert_equal(true, n3.reduced?)
    assert_equal(t.class, n3.class)
    assert_equal(t.type, n3.type)
    assert_equal(t.data, n3.data)
  end

  def test_triple_not_same_as_single_not
    t = QueryParser::Term.new('fred')

    n1 = QueryParser::Not.new(t)
    n2 = QueryParser::Not.new(n1)
    n3 = QueryParser::Not.new(n2)

    n4 = n3.reduce

    assert_equal(true, n4.reduced?)
    assert_equal(n1.class, n4.class)
    assert_equal(t.class, n4.contents.class)
    assert_equal(t.type, n4.contents.type)
    assert_equal(t.data, n4.contents.data)
  end

  def test_quadruple_not_same_as_double_not
    t = QueryParser::Term.new('fred')

    n1 = QueryParser::Not.new(t)
    n2 = QueryParser::Not.new(n1)
    n3 = QueryParser::Not.new(n2)
    n4 = QueryParser::Not.new(n3)

    n5 = n4.reduce

    assert_equal(true, n5.reduced?)
    assert_equal(t.class, n5.class)
    assert_equal(t.type, n5.type)
    assert_equal(t.data, n5.data)
  end
end
