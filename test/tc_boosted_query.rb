require 'test_helper'
class TC_Boosted_query < Minitest::Test
  def test_boost_plain_query
    qp = QueryParser.new('content', nil, 'title' => '^10')

    x = qp.parse('apple')

    assert_equal('content:apple title:apple^10', x)
  end

  def test_boost_only_positive_field
    qp = QueryParser.new('content', nil, 'title' => '^10')

    x = qp.parse('apple not banana')

    assert_equal('+(+content:apple -content:banana) title:apple^10', x)
  end

  def test_boost_combined_suffix
    qp = QueryParser.new('content', '~0.6', 'title' => '^10')

    x = qp.parse('apple not banana')

    assert_equal('+(+content:apple~0.6 -content:banana~0.6) title:apple~0.6^10', x)
  end

  def test_boost_multiple_boost
    qp = QueryParser.new('content', nil, 'title' => '^10', 'other' => '^20')

    x = qp.parse('apple')

    assert_equal('content:apple title:apple^10 other:apple^20', x)
  end

  def test_boost_multiple_boost_combined_suffix
    qp = QueryParser.new('content', '~0.6', 'title' => '^10', 'other' => '^20')

    x = qp.parse('apple')

    assert_equal('content:apple~0.6 title:apple~0.6^10 other:apple~0.6^20', x)
  end
end
