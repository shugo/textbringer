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

  def test_ispell_buffer
    insert("helllo world\nthis is a pen.")
    push_keys("rhello\n")
    ispell_buffer(recursive_edit: true)
    assert_equal("hello world\nthis is a pen.", Buffer.current.to_s)
    assert_equal("Finished spelling check.", Window.echo_area.message)
  end

  def test_ispell_buffer_last_word
    insert("hello world\nthis is a penn")
    push_keys("rpen\n")
    ispell_buffer(recursive_edit: true)
    assert_equal("hello world\nthis is a pen", Buffer.current.to_s)
    assert_equal("Finished spelling check.", Window.echo_area.message)
  end

  def test_ispell_buffer_not_modified
    insert("helllo world\nthis is a pen.")
    push_keys("q")
    ispell_buffer(recursive_edit: true)
    assert_equal("helllo world\nthis is a pen.", Buffer.current.to_s)
    assert_equal("Quitting spell check.", Window.echo_area.message)
  end

  def test_ispell_buffer_apostrophe
    insert("It shouldn't be corrected.")
    ispell_buffer(recursive_edit: true)
    assert_equal("It shouldn't be corrected.", Buffer.current.to_s)
    assert_equal("Finished spelling check.", Window.echo_area.message)
  end

  def test_ispell_buffer_not_stuck
    insert("テスト")
    ispell_buffer(recursive_edit: true)
    assert_equal("テスト", Buffer.current.to_s)
    assert_equal("Finished spelling check.", Window.echo_area.message)
  end

  def test_ispell_buffer_url
    insert("https://example.com/nosuchword")
    ispell_buffer(recursive_edit: true)
    assert_equal("https://example.com/nosuchword", Buffer.current.to_s)
    assert_equal("Finished spelling check.", Window.echo_area.message)
  end

  def test_ispell_buffer_email
    insert("nosuchword@example.com")
    ispell_buffer(recursive_edit: true)
    assert_equal("nosuchword@example.com", Buffer.current.to_s)
    assert_equal("Finished spelling check.", Window.echo_area.message)
  end

  def test_ispell_buffer_accept
    insert("helllo world\nthis is a pen.")
    push_keys("a")
    ispell_buffer(recursive_edit: true)
    assert_equal("helllo world\nthis is a pen.", Buffer.current.to_s)
    assert_equal("Finished spelling check.", Window.echo_area.message)
  end

  def test_ispell_buffer_insert
    insert("helllo world\nthis is a pen.")
    push_keys("in")
    ispell_buffer(recursive_edit: true)
    assert_equal("helllo world\nthis is a pen.", Buffer.current.to_s)
    assert_equal("Finished spelling check.", Window.echo_area.message)
  end
end
