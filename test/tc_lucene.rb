#!/usr/bin/ruby

require 'test/unit'
require 'queryparser'

class TC_Lucene < Test::Unit::TestCase
  APPLE=QueryParser::Term.new('apple')
  BANANA=QueryParser::Term.new('banana')
  CHERRY=QueryParser::Term.new('cherry')
  DAMSON=QueryParser::Term.new('damson')
  ELEPHANT=QueryParser::Term.new('elephant')
  FIG=QueryParser::Term.new('fig')
  QUOTED=QueryParser::Term.new('"killroy was here"')
  
  FIELD='content'

	def test_lucene_term_term
	  assert_equal("content:apple", APPLE.lucene('content'))
  end
	
	def test_lucne_term_quoted
	  assert_equal("content:\"killroy was here\"", QUOTED.lucene(FIELD))
  end

  # apple => apple
  def test_lucene_single_term
    assert_equal('content:apple', APPLE.lucene(FIELD))
  end

  # apple banana => +apple +banana => (+apple +banana)
  def test_lucene_and
    s = QueryParser::And.new
    s.add(APPLE)
    s.add(BANANA)
    
    assert_equal("(+content:apple +content:banana)", s.lucene(FIELD))
  end

  # apple or banana => (apple banana)
  def test_lucene_or
    s = QueryParser::Or.new
    s.add(APPLE)
    s.add(BANANA)
    
    assert_equal("(content:apple content:banana)", s.lucene(FIELD))
  end
  
  # apple not banana => (+apple -banana)
  def test_lucene_and_not_single_term
    s = QueryParser::And.new
    s.add(APPLE)
    s.add(QueryParser::Not.new(BANANA))
    
    assert_equal("(+content:apple -content:banana)", s.lucene(FIELD))
  end

  # apple not (banana or cherry) => +(+apple -(banana cherry))
  def test_lucene_and_not_or
    s = QueryParser::And.new
    s.add(APPLE)
    
    o = QueryParser::Or.new
    o.add(BANANA)
    o.add(CHERRY)
    s.add(QueryParser::Not.new(o))
    
    assert_equal("(+content:apple -(content:banana content:cherry))", s.lucene(FIELD))
  end
  
  # not apple => -apple
  def test_lucene_not
    n = QueryParser::Not.new(APPLE)
    
    assert_equal("-content:apple", n.lucene(FIELD))
  end
  
  # Set a suffix value
  def test_lucene_suffix_1
    t = QueryParser::Term.new('apple')
    
    assert_equal("content:apple~0.5", t.lucene(FIELD, '~0.5'))
  end
  
  def test_lucene_suffix_2
    s = QueryParser::And.new
    s.add(APPLE)
    s.add(QueryParser::Not.new(BANANA))
    
    assert_equal("(+content:apple~0.6 -content:banana~0.6)", s.lucene(FIELD, '~0.6'))
  end
end
