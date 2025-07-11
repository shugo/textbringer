# frozen_string_literal: true

require_relative "../../test_helper"
class TestIspell < Textbringer::TestCase
  def setup
    begin
      @ispell = Textbringer::Commands::Ispell.new
    rescue Errno::ENOENT
      omit "aspell command not found"
    end
  end

  def teardown
    @ispell&.close
  end

  def test_check_word_correct
    word, suggestions = @ispell.check_word("hello")
    assert_equal("hello", word)
    assert(suggestions.nil? || suggestions.empty?)
  end

  def test_check_word_incorrect
    word, suggestions = @ispell.check_word("helllo")
    assert_equal("helllo", word)
    assert_includes(suggestions, "hello")
  end
end
