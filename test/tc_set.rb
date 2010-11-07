#!/usr/bin/ruby

require 'test/unit'
require 'queryparser'

class TC_Set < Test::Unit::TestCase
  TOM = QueryParser::Term.new('tom')
  DICK = QueryParser::Term.new('dick')
  HARRY = QueryParser::Term.new('harry')
  THIS = QueryParser::Term.new('this')
  THAT = QueryParser::Term.new('that')
  OTHER = QueryParser::Term.new('other')

  def test_create
    s = QueryParser::And.new
    
    assert_equal(0, s.contents.size)
    assert_equal('<AND >', s.inspect)
  end

  def test_three_items_individually
    s = QueryParser::And.new

    assert_equal(0, s.contents.size)
    s.add(TOM)
    s.add(DICK)
    s.add(HARRY)
    assert_equal(3, s.contents.size)
  end

  def test_three_items_at_once
    s = QueryParser::And.new

    assert_equal(0, s.contents.size)
    s.add([TOM, DICK, HARRY])
    assert_equal(3, s.contents.size)
    assert_equal('<AND term:tom term:dick term:harry>', s.inspect)
    
    a = Array.new
    a << THIS
    a << THAT
    a << OTHER
    s.add(a)
    assert_equal(6, s.contents.size)
    assert_equal('<AND term:tom term:dick term:harry term:this term:that term:other>', s.inspect)
  end
  
  def test_another_way_to_add
    s = QueryParser::And.new

    s.add(TOM, [DICK, [HARRY], THIS], [[THAT, OTHER]])
    assert_equal(6, s.contents.size)
  end
end
