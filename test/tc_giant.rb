#!/usr/bin/ruby

# This test is a monster and takes a long time to run
# as it has 1,366,434 assertions to make. These tests
# were made to shake out any edge cases that I had not
# thought of.
#
# It found three that had not appeared in testing so
# I like to keep them around but don't run them all the
# time.

require 'test/unit'
require 'queryparser'

class TC_Giant < Test::Unit::TestCase
	def test_valid
	  qp = QueryParser.new('content')
	  counter = 0
	
	  File.open('test/all_valid.txt') do |f|
	    f.each do |l|
        counter += 1
        l.chomp!
        assert_nothing_raised "line #{counter} #{l}" do
          qp.parse(l)
        end
      end
    end
  end

	def test_invalid
	  qp = QueryParser.new('content')
	
	  File.open('test/all_invalid.txt') do |f|
	    f.each do |l|
        l.chomp!
        assert_raise QueryParser::Exceptions::MalformedQuery, QueryParser::Exceptions::UnbalancedBraces, QueryParser::Exceptions::EmptyQuery do
          qp.parse(l)
        end
      end
    end
  end
end
