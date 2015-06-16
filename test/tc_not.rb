require 'test_helper'

class TC_Not < Minitest::Test
  def test_create_with_data
    n = QueryParser::Not.new('fred')
    assert_equal(QueryParser::Not, n.class)
    assert_equal('<NOT "fred">', n.inspect)
  end

  def test_create_with_term
    n = QueryParser::Not.new(QueryParser::Term.new('fred'))
    assert_equal(QueryParser::Not, n.class)
    assert_equal('<NOT term:fred>', n.inspect)
  end

  def test_create_with_empty_string
    n = QueryParser::Not.new('')
    assert_equal(QueryParser::Not, n.class)
    assert_equal('<NOT "">', n.inspect)
  end

  def test_create_with_nil
    n = QueryParser::Not.new(nil)
    assert_equal(QueryParser::Not, n.class)
    assert_equal('<NOT nil>', n.inspect)
  end
end
