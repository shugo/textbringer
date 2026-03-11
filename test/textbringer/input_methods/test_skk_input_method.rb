require_relative "../../test_helper"

class TestSKKInputMethod < Textbringer::TestCase
  SKK_TEST_DICT = File.expand_path("../../fixtures/SKK-JISYO.test", __dir__)

  setup do
    CONFIG[:skk_dictionary_path] = SKK_TEST_DICT
    @buffer = Buffer.new_buffer("test")
    @buffer.toggle_input_method("skk")
    @im = @buffer.input_method
    switch_to_buffer(@buffer)
  end

  teardown do
    CONFIG.delete(:skk_dictionary)
  end

  # --- Hiragana mode ---

  def test_hiragana_basic
    @im.handle_event("k")
    @im.handle_event("a")
    assert_equal("か", @buffer.to_s)
  end

  def test_hiragana_punctuation
    @im.handle_event(",")
    @im.handle_event(".")
    assert_equal("、。", @buffer.to_s)
  end

  def test_katakana_punctuation
    @im.handle_event("q")
    @im.handle_event(",")
    @im.handle_event(".")
    assert_equal("、。", @buffer.to_s)
  end

  def test_hiragana_nn
    @im.handle_event("n")
    @im.handle_event("n")
    assert_equal("ん", @buffer.to_s)
  end

  def test_hiragana_n_before_consonant
    @im.handle_event("n")
    @im.handle_event("k")
    @im.handle_event("a")
    assert_equal("んか", @buffer.to_s)
  end

  def test_hiragana_multi_char_sequence
    @im.handle_event("s")
    @im.handle_event("h")
    @im.handle_event("a")
    assert_equal("しゃ", @buffer.to_s)
  end

  def test_hiragana_double_consonant
    @im.handle_event("k")
    @im.handle_event("k")
    @im.handle_event("a")
    assert_equal("っか", @buffer.to_s)
  end

  # --- Mode switching ---

  def test_ctrl_j_sets_hiragana
    @im.handle_event("l")       # switch to ASCII
    @im.handle_event("\C-j")    # back to hiragana
    @im.handle_event("a")
    assert_equal("あ", @buffer.to_s)
  end

  def test_q_switches_to_katakana
    @im.handle_event("q")
    assert_equal("ア", @im.status)
  end

  def test_q_switches_back_to_hiragana
    @im.handle_event("q")
    @im.handle_event("q")
    assert_equal("あ", @im.status)
  end

  def test_l_switches_to_ascii
    @im.handle_event("l")
    assert_equal("A", @im.status)
  end

  def test_L_switches_to_zenkaku_ascii
    @im.handle_event("L")
    assert_equal("Ａ", @im.status)
  end

  # --- Katakana mode ---

  def test_katakana_basic
    @im.handle_event("q")
    @im.handle_event("k")
    @im.handle_event("a")
    assert_equal("カ", @buffer.to_s)
  end

  def test_katakana_nn
    @im.handle_event("q")
    @im.handle_event("n")
    @im.handle_event("n")
    assert_equal("ン", @buffer.to_s)
  end

  # --- ASCII mode ---

  def test_ascii_passthrough
    @im.handle_event("l")
    result = @im.handle_event("a")
    # ASCII mode returns char directly (controller inserts it)
    assert_equal("a", result)
  end

  def test_ascii_uppercase_passthrough
    @im.handle_event("l")
    result = @im.handle_event("A")
    assert_equal("A", result)
  end

  # --- Zenkaku ASCII mode ---

  def test_zenkaku_ascii
    @im.handle_event("L")
    result = @im.handle_event("a")
    # Zenkaku mode returns converted char directly (controller inserts it)
    assert_equal("ａ", result)
  end

  def test_zenkaku_ascii_uppercase
    @im.handle_event("L")
    result = @im.handle_event("A")
    assert_equal("Ａ", result)
  end

  # --- Special key passthrough ---

  def test_special_key_passthrough
    @im.handle_event("k")
    result = @im.handle_event(:right)
    assert_equal(:right, result)
    assert_equal("", @buffer.to_s)
  end

  def test_ctrl_h_passes_through_normal
    result = @im.handle_event("\C-h")
    assert_equal("\C-h", result)
    assert_equal("", @buffer.to_s)
  end

  def test_ctrl_backslash_passes_through_normal
    result = @im.handle_event("\C-\\")
    assert_equal("\C-\\", result)
    assert_equal("", @buffer.to_s)
  end

  def test_ctrl_h_clears_roman_buffer
    @im.handle_event("k")  # buffered prefix
    result = @im.handle_event("\C-h")
    assert_equal("\C-h", result)
    assert_equal("", @buffer.to_s)
  end

  def test_ctrl_h_passes_through_converting
    @im.handle_event("K")
    @im.handle_event("a")
    result = @im.handle_event("\C-h")
    # C-h commits the conversion (removes ▽, keeps kana) and passes through
    assert_equal("\C-h", result)
    assert_equal("か", @buffer.to_s)
    assert_equal("あ", @im.status)
  end

  def test_ctrl_h_passes_through_selecting
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event(" ")
    first = @buffer.to_s.sub(/\A▼/, "")
    result = @im.handle_event("\C-h")
    # C-h confirms the selection and passes through
    assert_equal("\C-h", result)
    assert_equal(first, @buffer.to_s)
    assert_equal("あ", @im.status)
  end

  # --- Converting phase ---

  def test_converting_starts_with_uppercase
    @im.handle_event("K")
    assert_equal("▽", @im.status)
    assert_equal("▽", @buffer.to_s)
  end

  def test_converting_accumulates_yomi
    @im.handle_event("K")
    @im.handle_event("a")
    assert_equal("▽か", @buffer.to_s)
  end

  def test_converting_multiple_kana
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event("n")
    @im.handle_event("j")
    @im.handle_event("i")
    assert_equal("▽かんじ", @buffer.to_s)
  end

  def test_cancel_converting
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event("\C-g")
    assert_equal("", @buffer.to_s)
    assert_equal("あ", @im.status)
  end

  def test_confirm_kana_with_ctrl_j
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event("\C-j")
    assert_equal("か", @buffer.to_s)
    assert_equal("あ", @im.status)
  end

  def test_non_string_event_commits_converting
    @im.handle_event("K")
    @im.handle_event("a")
    result = @im.handle_event(:right)
    assert_equal(:right, result)
    # ▽ is removed, kana remains
    assert_equal("か", @buffer.to_s)
  end

  # --- Selecting phase ---

  def test_space_triggers_lookup
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event("n")
    @im.handle_event("j")
    @im.handle_event("i")
    @im.handle_event(" ")
    assert_equal("▼", @im.status)
    # Buffer should start with ▼ followed by a kanji candidate
    assert_match(/\A▼/, @buffer.to_s)
  end

  def test_no_conversion_found
    @im.handle_event("A")
    # type something unlikely to be in the dict
    @im.handle_event("x")
    @im.handle_event("x")
    @im.handle_event("x")
    @im.handle_event(" ")
    # Should still be in converting phase (no candidates)
    assert_equal("▽", @im.status)
  end

  def test_confirm_selection_with_enter
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event("n")
    @im.handle_event("j")
    @im.handle_event("i")
    @im.handle_event(" ")
    first_candidate = @buffer.to_s.sub(/\A▼/, "")
    @im.handle_event("\r")
    assert_equal(first_candidate, @buffer.to_s)
    assert_equal("あ", @im.status)
  end

  def test_confirm_selection_with_ctrl_m
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event(" ")
    first = @buffer.to_s.sub(/\A▼/, "")
    @im.handle_event("\C-m")
    assert_equal(first, @buffer.to_s)
  end

  def test_cycle_candidates_with_space
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event(" ")
    first = @buffer.to_s.dup
    @im.handle_event(" ")
    second = @buffer.to_s.dup
    # Either we wrapped around (only 1 candidate) or got a different candidate
    assert_match(/\A▼/, first)
    assert_match(/\A▼/, second)
  end

  def test_prev_candidate_with_x
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event("n")
    @im.handle_event("j")
    @im.handle_event("i")
    @im.handle_event(" ")
    first = @buffer.to_s.dup
    @im.handle_event(" ")
    second = @buffer.to_s.dup
    @im.handle_event("x")
    assert_equal(first, @buffer.to_s)
  end

  def test_cancel_selecting_restores_converting
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event(" ")
    @im.handle_event("\C-g")
    assert_equal("▽", @im.status)
    assert_equal("▽か", @buffer.to_s)
  end

  def test_non_space_confirms_and_reprocesses
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event(" ")
    first = @buffer.to_s.sub(/\A▼/, "")
    # pressing "a" should confirm and then insert "あ"
    @im.handle_event("a")
    assert_equal(first + "あ", @buffer.to_s)
  end

  # --- Okuri-ari (okurigana) ---

  def test_okurigana_triggers_lookup
    # Type "書K" sequence: K starts converting, a gives か yomi, K starts okurigana
    @im.handle_event("K")  # start converting
    @im.handle_event("a")  # yomi = か
    @im.handle_event("K")  # start okurigana with 'k'
    @im.handle_event("u")  # okurigana kana = く, triggers lookup
    # Should now be in selecting phase with ▼
    assert_equal("▼", @im.status)
    assert_match(/\A▼/, @buffer.to_s)
    assert_match(/く\z/, @buffer.to_s)
  end

  def test_okurigana_single_vowel_lookup
    # "KaU": yomi=か, okurigana is just the vowel "u"="う", lookup key "かu"
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event("U")
    assert_equal("▼", @im.status)
    assert_match(/\A▼/, @buffer.to_s)
    assert_match(/う\z/, @buffer.to_s)
  end

  def test_okurigana_single_vowel_confirm
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event("U")
    @im.handle_event("\r")
    assert_equal("買う", @buffer.to_s)
  end

  def test_okurigana_vowel_start_selecting
    # "KaE": capital vowel immediately completes okurigana "え" and triggers lookup
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event("E")
    assert_equal("▼", @im.status)
    assert_match(/\A▼/, @buffer.to_s)
    assert_match(/え\z/, @buffer.to_s)
  end

  def test_okurigana_vowel_start_kaeru
    # "KaEru": E triggers lookup, r confirms, ru inserts "る" → "変える"
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event("E")
    @im.handle_event("r")
    @im.handle_event("u")
    assert_equal("変える", @buffer.to_s)
  end

  # --- Hankaku katakana mode ---

  def test_ctrl_q_switches_to_hankaku_katakana
    @im.handle_event("\C-q")
    assert_equal("ｱ", @im.status)
  end

  def test_ctrl_q_switches_back_to_hiragana
    @im.handle_event("\C-q")
    @im.handle_event("\C-q")
    assert_equal("あ", @im.status)
  end

  def test_hankaku_katakana_basic
    @im.handle_event("\C-q")
    @im.handle_event("k")
    @im.handle_event("a")
    assert_equal("ｶ", @buffer.to_s)
  end

  def test_hankaku_katakana_punctuation
    @im.handle_event("\C-q")
    @im.handle_event(",")
    @im.handle_event(".")
    assert_equal("､｡", @buffer.to_s)
  end

  # --- Mode-switch key passthrough in ASCII/zenkaku modes ---

  def test_q_passes_through_in_ascii
    @im.handle_event("l")
    result = @im.handle_event("q")
    assert_equal("q", result)
    assert_equal("A", @im.status)
  end

  def test_l_passes_through_in_ascii
    @im.handle_event("l")
    result = @im.handle_event("l")
    assert_equal("l", result)
    assert_equal("A", @im.status)
  end

  def test_L_passes_through_in_zenkaku
    @im.handle_event("L")
    result = @im.handle_event("L")
    assert_equal("Ｌ", result)
    assert_equal("Ａ", @im.status)
  end

  def test_roman_buffer_cleared_on_mode_switch
    @im.handle_event("k")     # pending romaji prefix
    @im.handle_event("l")     # switch to ASCII (clears roman_buffer)
    @im.handle_event("\C-j")  # switch back to hiragana
    @im.handle_event("a")     # should insert "あ", not "か"
    assert_equal("あ", @buffer.to_s)
  end

  def test_roman_buffer_cleared_after_confirm_selecting
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event(" ")
    @im.handle_event("\r")    # confirm selection
    # roman_buffer is empty; typing "a" now should produce "あ" cleanly
    @im.handle_event("a")
    candidate = @buffer.to_s
    assert_match(/あ\z/, candidate)
  end

  # --- SKK server client ---

  class TestSKKServerClient < Textbringer::TestCase
    def setup
      super
      # Start a minimal TCP server on an ephemeral port
      @server = TCPServer.new("127.0.0.1", 0)
      @port = @server.addr[1]
      @server_thread = Thread.new do
        loop do
          begin
            client = @server.accept
          rescue IOError
            break
          end
          Thread.new(client) do |c|
            while (line = c.gets("\n"))
              line = line.encode("UTF-8", "EUC-JP", invalid: :replace, undef: :replace)
              if line.start_with?("0")
                c.close
                break
              elsif line.start_with?("1")
                key = line[1..].strip
                if key == "かんじ"
                  c.write("1/漢字/感じ/\n".encode("EUC-JP"))
                else
                  c.write("4#{key} \n".encode("EUC-JP"))
                end
              end
            end
          end
        end
      end

      CONFIG[:skk_server_host] = "127.0.0.1"
      CONFIG[:skk_server_port] = @port
      @buffer = Buffer.new_buffer("test_server")
      @buffer.toggle_input_method("skk")
      @im = @buffer.input_method
      switch_to_buffer(@buffer)
    end

    def teardown
      @im.disable
      CONFIG[:skk_server_host] = nil
      CONFIG[:skk_server_port] = 1178
      @server.close rescue nil
      @server_thread.kill
      @server_thread.join(1)
      super
    end

    def test_server_returns_candidates
      @im.handle_event("K")
      @im.handle_event("a")
      @im.handle_event("n")
      @im.handle_event("j")
      @im.handle_event("i")
      @im.handle_event(" ")
      assert_equal("▼", @im.status)
      assert_match(/\A▼/, @buffer.to_s)
    end

    def test_server_not_found
      @im.handle_event("A")
      @im.handle_event("x")
      @im.handle_event("x")
      @im.handle_event("x")
      @im.handle_event(" ")
      # No conversion: stays in converting phase
      assert_equal("▽", @im.status)
    end

    def test_no_server_host_uses_local_dict
      CONFIG[:skk_server_host] = nil
      CONFIG[:skk_dictionary_path] = SKK_TEST_DICT
      buf = Buffer.new_buffer("local_test")
      buf.toggle_input_method("skk")
      im = buf.input_method
      switch_to_buffer(buf)
      im.handle_event("K")
      im.handle_event("a")
      im.handle_event(" ")
      # With local dict, か should have a candidate
      assert_equal("▼", im.status)
      assert_nil(im.instance_variable_get(:@skk_server_socket))
    ensure
      CONFIG[:skk_server_host] = nil
    end

    def test_connection_refused_graceful
      CONFIG[:skk_server_host] = "127.0.0.1"
      CONFIG[:skk_server_port] = 1  # nothing listening here
      @im.handle_event("K")
      @im.handle_event("a")
      assert_raise(Errno::ECONNREFUSED) do
        @im.handle_event(" ")
      end
      # graceful: no crash, stays in converting or shows no conversion
      assert([:converting, :normal].include?(@im.instance_variable_get(:@phase)))
    ensure
      CONFIG[:skk_server_port] = @port
    end

    def test_server_mode_does_not_load_local_dict
      @im.handle_event("K")
      @im.handle_event("a")
      @im.handle_event("n")
      @im.handle_event("j")
      @im.handle_event("i")
      @im.handle_event(" ")
      assert_nil(@im.instance_variable_get(:@okuriiari))
      assert_nil(@im.instance_variable_get(:@okurinasi))
    end

    def test_disable_closes_socket
      @im.handle_event("K")
      @im.handle_event("a")
      @im.handle_event("n")
      @im.handle_event("j")
      @im.handle_event("i")
      @im.handle_event(" ")
      # Socket should have been created
      refute_nil(@im.instance_variable_get(:@skk_server_socket))
      @im.disable
      assert_nil(@im.instance_variable_get(:@skk_server_socket))
    end
  end

  # --- Status display ---

  def test_status_hiragana
    assert_equal("あ", @im.status)
  end

  def test_status_katakana
    @im.handle_event("q")
    assert_equal("ア", @im.status)
  end

  def test_status_ascii
    @im.handle_event("l")
    assert_equal("A", @im.status)
  end

  def test_status_zenkaku
    @im.handle_event("L")
    assert_equal("Ａ", @im.status)
  end

  def test_status_converting
    @im.handle_event("K")
    assert_equal("▽", @im.status)
  end

  def test_status_selecting
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event(" ")
    assert_equal("▼", @im.status)
  end
end
