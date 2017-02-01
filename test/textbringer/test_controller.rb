require_relative "../test_helper"

class TestController < Textbringer::TestCase
  def test_undefined_key
    push_keys "\C-x\C-a\n"
    map = Keymap.new
    map.define_key("\n", :exit_recursive_edit)
    set_transient_map(map)
    recursive_edit
    assert_match(/^\C-x \C-a is undefined\n\z/, Buffer["*Messages*"].to_s)
  end
end
