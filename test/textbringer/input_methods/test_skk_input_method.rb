require_relative "../../test_helper"

class TestSKKInputMethod < Textbringer::TestCase
  SKK_TEST_DICT = File.expand_path("../../fixtures/SKK-JISYO.test", __dir__)

  setup do
    CONFIG[:skk_dictionary_path] = SKK_TEST_DICT
    # Point at a fresh temp path so tests never read or write the real
    # user dictionary in the developer's home directory.
    @user_dict_dir = Dir.mktmpdir
    CONFIG[:skk_user_dictionary_path] = File.join(@user_dict_dir, "skk-jisyo.utf8")
    @buffer = Buffer.new_buffer("test")
    @buffer.toggle_input_method("skk")
    @im = @buffer.input_method
    switch_to_buffer(@buffer)
  end

  teardown do
    CONFIG.delete(:skk_dictionary)
    FileUtils.remove_entry(@user_dict_dir) if @user_dict_dir
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
    assert_equal("カナ", @im.status)
  end

  def test_q_switches_back_to_hiragana
    @im.handle_event("q")
    @im.handle_event("q")
    assert_equal("かな", @im.status)
  end

  def test_l_switches_to_ascii
    @im.handle_event("l")
    assert_equal("SKK:", @im.status)
  end

  def test_L_switches_to_zenkaku_ascii
    @im.handle_event("L")
    assert_equal("全英", @im.status)
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

  # --- Converting phase in katakana mode ---
  #
  # Mirrors ddskk: skk-rom-kana-base-rule-list pairs each kana with its
  # katakana form and skk-kana-input picks one by skk-katakana, so a
  # katakana-mode headword is katakana from the first kana onward --
  # it is not hiragana that gets converted to katakana afterward.

  def test_katakana_mode_converting_shows_katakana_while_composing
    @im.handle_event("q") # switch to katakana mode
    @im.handle_event("T")
    @im.handle_event("e")
    assert_equal("▽テ", @buffer.to_s)
  end

  def test_katakana_mode_dictionary_lookup_uses_hiragana_key
    # The headword is displayed as katakana, but the dictionary (keyed in
    # hiragana) must still be searched correctly.
    @im.handle_event("q") # switch to katakana mode
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event("n")
    @im.handle_event("j")
    @im.handle_event("i")
    assert_equal("▽カンジ", @buffer.to_s)
    @im.handle_event(" ")
    assert_equal("▼漢字", @buffer.to_s)
  end

  def test_katakana_mode_okurigana_kana_stays_katakana
    # Mirrors ddskk section 6.3.4: okurigana in a katakana-mode conversion
    # stays katakana even though the dictionary lookup itself uses hiragana.
    @im.handle_event("q") # switch to katakana mode
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event("U") # okurigana vowel "u" -> lookup key "かu"
    assert_equal("▼買ウ", @buffer.to_s)
  end

  def test_hankaku_katakana_mode_converting_is_unaffected
    # Half-width katakana mode is intentionally left out of this: it isn't
    # hiragana-convertible for the dictionary lookup key the way full-width
    # katakana is, and ddskk's half-width kana input is a separate mode
    # with its own conversion path, not part of skk-katakana.
    @im.handle_event("\C-q") # switch to hankaku katakana mode
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event("n")
    @im.handle_event("j")
    @im.handle_event("i")
    assert_equal("▽かんじ", @buffer.to_s)
    @im.handle_event(" ")
    assert_equal("▼漢字", @buffer.to_s)
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

  def test_ctrl_h_during_converting_erases_last_yomi_char_instead_of_committing
    @im.handle_event("K")
    @im.handle_event("a")
    result = @im.handle_event("\C-h")
    # ddskk-like: the headword is composed one character at a time, so
    # backspace steps it back instead of committing the conversion.
    assert_nil(result)
    assert_equal("▽", @buffer.to_s)
    assert_equal("かな", @im.status)
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
    assert_equal("かな", @im.status)
  end

  # --- Converting phase ---

  def test_converting_starts_with_uppercase
    @im.handle_event("K")
    assert_equal("かな", @im.status)
    assert_equal("▽k", @buffer.to_s)
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
    assert_equal("かな", @im.status)
  end

  def test_ctrl_g_clears_a_lingering_message
    # "q" with unconfirmed romaji paints "There remains a kana prefix"
    # (see test_q_with_unconfirmed_romaji_paints_the_message_immediately).
    # cancel_converting already calls Window.redisplay to reflect the
    # cancelled conversion, but that redisplay would otherwise repaint the
    # echo area with this now-stale message too, since nothing cleared it.
    @im.handle_event("T")
    @im.handle_event("k")
    @im.handle_event("q")
    assert_equal(["There remains a kana prefix"], Window.echo_area.window.contents)

    @im.handle_event("\C-g")
    assert_nil(Window.echo_area.message)
    assert_equal([""], Window.echo_area.window.contents)
  end

  def test_confirm_kana_with_ctrl_j
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event("\C-j")
    assert_equal("か", @buffer.to_s)
    assert_equal("かな", @im.status)
  end

  # --- Unconfirmed romaji preview during converting phase ---

  def test_converting_shows_unconfirmed_romaji_prefix
    @im.handle_event("T")
    assert_equal("▽t", @buffer.to_s)
    @im.handle_event("o")
    assert_equal("▽と", @buffer.to_s)
  end

  def test_converting_multi_char_prefix_preview
    @im.handle_event("K")
    @im.handle_event("y")
    assert_equal("▽ky", @buffer.to_s)
    @im.handle_event("o")
    assert_equal("▽きょ", @buffer.to_s)
  end

  def test_converting_geminate_keeps_preview_of_second_consonant
    @im.handle_event("K")
    @im.handle_event("k")
    assert_equal("▽っk", @buffer.to_s)
    @im.handle_event("a")
    assert_equal("▽っか", @buffer.to_s)
  end

  def test_cancel_converting_discards_unconfirmed_romaji_preview
    @im.handle_event("T")
    @im.handle_event("\C-g")
    assert_equal("", @buffer.to_s)
  end

  def test_confirm_with_ctrl_j_discards_unconfirmed_romaji_preview
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event("k")
    @im.handle_event("\C-j")
    assert_equal("か", @buffer.to_s)
  end

  def test_okurigana_shows_unconfirmed_romaji_preview
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event("K")
    # ddskk-like: entering okurigana inserts a "*" marker before the
    # in-progress romaji.
    assert_equal("▽か*k", @buffer.to_s)
  end

  def test_non_string_event_commits_converting
    @im.handle_event("K")
    @im.handle_event("a")
    result = @im.handle_event(:right)
    assert_equal(:right, result)
    # ▽ is removed, kana remains
    assert_equal("か", @buffer.to_s)
  end

  # --- Backspace during converting phase (ddskk-like step-back) ---

  def test_backspace_erases_unconfirmed_romaji_preview_first
    @im.handle_event("T")
    @im.handle_event("o")
    @im.handle_event("u")
    @im.handle_event("k")
    @im.handle_event("y")
    assert_equal("▽とうky", @buffer.to_s)
    @im.handle_event("\C-h")
    assert_equal("▽とうk", @buffer.to_s)
    @im.handle_event("\C-h")
    assert_equal("▽とう", @buffer.to_s)
  end

  def test_backspace_erases_yomi_one_kana_at_a_time
    @im.handle_event("T")
    @im.handle_event("o")
    @im.handle_event("u")
    @im.handle_event("\C-h")
    assert_equal("▽と", @buffer.to_s)
    @im.handle_event("\C-h")
    assert_equal("▽", @buffer.to_s)
  end

  def test_backspace_cancels_converting_once_yomi_is_empty
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event("\C-h")
    assert_equal("▽", @buffer.to_s)
    result = @im.handle_event("\C-h")
    assert_nil(result)
    assert_equal("", @buffer.to_s)
    assert_equal("かな", @im.status)
  end

  def test_backspace_cancels_okurigana_consonant_before_touching_yomi
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event("K") # starts okurigana with consonant "k"
    assert_equal("▽か*k", @buffer.to_s)
    @im.handle_event("\C-h")
    # Okurigana (and its "*" marker) is dropped, but the headword "か" is untouched
    assert_equal("▽か", @buffer.to_s)
    @im.handle_event("\C-h")
    assert_equal("▽", @buffer.to_s)
  end

  def test_backspace_after_confirmed_geminate_only_erases_preview
    # "KaTt": T starts okurigana with "t", the second "t" confirms the
    # geminate "っ" and re-buffers "t" as the next consonant preview.
    # Backspace here must drop only the "t" preview, not the already
    # confirmed "っ" or the okurigana marker itself.
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event("T")
    @im.handle_event("t")
    assert_equal("▽か*っt", @buffer.to_s)
    @im.handle_event("\C-h")
    assert_equal("▽か*っ", @buffer.to_s)
    @im.handle_event("\C-h")
    assert_equal("▽か*", @buffer.to_s)
    @im.handle_event("\C-h")
    assert_equal("▽か", @buffer.to_s)
  end

  def test_backspace_symbol_behaves_like_ctrl_h_during_converting
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event(:backspace)
    assert_equal("▽", @buffer.to_s)
  end

  # --- Selecting phase ---

  def test_space_triggers_lookup
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event("n")
    @im.handle_event("j")
    @im.handle_event("i")
    @im.handle_event(" ")
    assert_equal("かな", @im.status)
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
    assert_equal("かな", @im.status)
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
    assert_equal("かな", @im.status)
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
    @im.handle_event("x")
    assert_equal(first, @buffer.to_s)
  end

  def test_cancel_selecting_restores_converting
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event(" ")
    @im.handle_event("\C-g")
    assert_equal("かな", @im.status)
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
    assert_equal("かな", @im.status)
    assert_match(/\A▼/, @buffer.to_s)
    assert_match(/く\z/, @buffer.to_s)
  end

  def test_okurigana_single_vowel_lookup
    # "KaU": yomi=か, okurigana is just the vowel "u"="う", lookup key "かu"
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event("U")
    assert_equal("かな", @im.status)
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
    assert_equal("かな", @im.status)
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

  def test_okurigana_geminate_consonant_does_not_leak_into_yomi
    # "KaTta": okurigana "った" (small tsu + ta) starts with consonant "t".
    # The geminate "っ" must land in the okurigana, not the yomi, or the
    # dictionary lookup key ("か" + "t") gets corrupted.
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event("T") # starts okurigana with consonant "t"
    @im.handle_event("t")
    @im.handle_event("a")
    # start_selecting has already fired (kana confirmed while okurigana was
    # active) and snapshotted these into @yomi/@okuri_kana before replacing
    # the buffer text with the "▼" candidate.
    assert_equal("か", @im.instance_variable_get(:@yomi))
    assert_equal("った", @im.instance_variable_get(:@okuri_kana))
    assert_match(/\A▼/, @buffer.to_s)
    assert_match(/った\z/, @buffer.to_s)
  end

  def test_okurigana_geminate_consonant_confirm
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event("T")
    @im.handle_event("t")
    @im.handle_event("a")
    @im.handle_event("\r")
    assert_equal("勝った", @buffer.to_s)
  end

  def test_okurigana_n_flush_does_not_leak_into_yomi
    # "N" starts okurigana with consonant "n"; a following consonant that
    # isn't n/y/a/i/u/e/o flushes "ん" into the okurigana, not the yomi.
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event("N")
    @im.handle_event("d")
    assert_equal("か", @im.send(:current_yomi))
    assert_equal("んd", @im.send(:current_okuri_kana))
  end

  def test_cancel_selecting_drops_okurigana_distinction
    # Mirrors ddskk's skk-previous-candidate: cancelling out of the
    # candidate list (▼) does not restore the "*" marker -- the okurigana
    # text rejoins the yomi as plain, un-marked headword text.
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event("T")
    @im.handle_event("t")
    @im.handle_event("a") # confirms "った", triggers lookup -> selecting
    assert_match(/\A▼/, @buffer.to_s)
    @im.handle_event("\C-g") # cancel selecting, back to converting
    assert_equal("▽かった", @buffer.to_s)
    assert_equal("かな", @im.status)
    # Backspace now treats "た" as ordinary headword text, not okurigana.
    @im.handle_event("\C-h")
    assert_equal("▽かっ", @buffer.to_s)
  end

  # --- User dictionary (learning and persistence, mirrors ddskk's
  # skk-update-jisyo-1: confirmed candidates move to the front of their
  # entry and are saved immediately) ---

  def test_confirming_a_non_first_candidate_learns_it
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event(" ") # candidates: 加/可/化/課/廊 (see SKK-JISYO.test)
    @im.handle_event(" ")
    @im.handle_event(" ") # advance to the 3rd candidate, "化"
    @im.handle_event("\r")
    assert_equal("化", @buffer.to_s)
    assert_equal(
      ";; okuri-ari entries.\n;; okuri-nasi entries.\nか /化/\n",
      File.read(CONFIG[:skk_user_dictionary_path])
    )
  end

  def test_learned_candidate_is_offered_first_on_next_lookup
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event(" ")
    @im.handle_event(" ")
    @im.handle_event(" ")
    @im.handle_event("\r") # learn "化" for "か"

    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event(" ")
    assert_equal(["化", "加", "可", "課", "廊"], @im.instance_variable_get(:@candidates))
  end

  def test_reconfirming_a_different_candidate_reorders_learning
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event(" ")
    @im.handle_event(" ")
    @im.handle_event(" ")
    @im.handle_event("\r") # learn "化" first

    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event(" ") # candidates now start with "化"
    @im.handle_event(" ")
    @im.handle_event("\r") # pick the 2nd one, "加", learn it instead
    assert_equal("化加", @buffer.to_s)

    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event(" ")
    assert_equal(["加", "化", "可", "課", "廊"], @im.instance_variable_get(:@candidates))
  end

  def test_okuri_ari_candidate_is_learned_and_persisted
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event("U") # okurigana vowel "u" -> lookup key "かu" -> 買
    @im.handle_event("\r")
    assert_equal("買う", @buffer.to_s)
    assert_equal(
      ";; okuri-ari entries.\nかu /買/\n;; okuri-nasi entries.\n",
      File.read(CONFIG[:skk_user_dictionary_path])
    )
  end

  def test_missing_user_dictionary_file_is_ignored
    CONFIG[:skk_user_dictionary_path] = File.join(@user_dict_dir, "does-not-exist", "skk-jisyo.utf8")
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event(" ")
    assert_equal(["加", "可", "化", "課", "廊"], @im.instance_variable_get(:@candidates))
  end

  # --- Registering a new word when no candidate is found (mirrors ddskk's
  # skk-henkan-in-minibuff) ---

  def test_no_candidate_prompts_registration_and_saves_it
    @im.define_singleton_method(:read_from_minibuffer) { |prompt| "しんご" }
    %w[T e s u t o].each { |c| @im.handle_event(c) } # "てすと" has no dictionary entry
    @im.handle_event(" ")
    assert_equal("しんご", @buffer.to_s)
    assert_equal("かな", @im.status)
    assert_equal(
      ";; okuri-ari entries.\n;; okuri-nasi entries.\nてすと /しんご/\n",
      File.read(CONFIG[:skk_user_dictionary_path])
    )
  end

  def test_registration_prompt_includes_okuri_roman
    seen_prompt = nil
    @im.define_singleton_method(:read_from_minibuffer) do |prompt|
      seen_prompt = prompt
      "しんぱい"
    end
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event("Z") # okurigana consonant "z", not in the test dict
    @im.handle_event("a") # confirms okurigana kana "ざ"; lookup key "かz" not found
    assert_equal("SKK register か*z: ", seen_prompt)
    assert_equal("しんぱいざ", @buffer.to_s)
    assert_equal(
      ";; okuri-ari entries.\nかz /しんぱい/\n;; okuri-nasi entries.\n",
      File.read(CONFIG[:skk_user_dictionary_path])
    )
  end

  def test_empty_registration_cancels_without_saving
    @im.define_singleton_method(:read_from_minibuffer) { |prompt| "" }
    %w[T e s u t o].each { |c| @im.handle_event(c) }
    @im.handle_event(" ")
    assert_equal("▽てすと", @buffer.to_s)
    assert_equal(:converting, @im.instance_variable_get(:@phase))
    refute(File.exist?(CONFIG[:skk_user_dictionary_path]))
  end

  def test_empty_registration_paints_the_message_immediately
    # Same pattern as toggle_yomi_katakana's "There remains a kana prefix"
    # (PR #270): message() only updates the echo area's in-memory content,
    # so an explicit Window.redisplay is needed to actually paint it.
    @im.define_singleton_method(:read_from_minibuffer) { |prompt| "" }
    %w[T e s u t o].each { |c| @im.handle_event(c) }
    @im.handle_event(" ")
    assert_equal("No conversion: てすと", Window.echo_area.message)
    assert_equal(["No conversion: てすと"], Window.echo_area.window.contents)
  end

  def test_registration_clears_a_lingering_message_before_prompting
    # register_new_word must clear a lingering message before showing its
    # prompt, or EchoArea#redisplay would draw the stale message instead
    # of the prompt (it only draws @prompt when @message is nil).
    message("No conversion: dummy") # simulate a message left over from earlier

    message_when_prompting = :not_captured
    @im.define_singleton_method(:read_from_minibuffer) do |prompt|
      message_when_prompting = Window.echo_area.message
      ""
    end
    %w[T e s u t o].each { |c| @im.handle_event(c) }
    @im.handle_event(" ")
    assert_nil(message_when_prompting)
  end

  def test_registered_word_is_offered_first_on_next_lookup
    @im.define_singleton_method(:read_from_minibuffer) { |prompt| "しんご" }
    %w[T e s u t o].each { |c| @im.handle_event(c) }
    @im.handle_event(" ")

    %w[T e s u t o].each { |c| @im.handle_event(c) }
    @im.handle_event(" ")
    assert_equal(["しんご"], @im.instance_variable_get(:@candidates))
  end

  # --- Toggling yomi to katakana with "q" (ddskk's skk-toggle-characters) ---

  def test_q_converts_yomi_to_katakana_and_commits
    %w[T e k i s u t o q].each { |c| @im.handle_event(c) }
    assert_equal("テキスト", @buffer.to_s)
    assert_equal("かな", @im.status)
  end

  def test_q_converts_katakana_yomi_back_to_hiragana
    %w[T e k i s u t o q].each { |c| @im.handle_event(c) }
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event("t")
    @im.handle_event("a")
    @im.handle_event("k")
    @im.handle_event("a")
    @im.handle_event("n")
    @im.handle_event("a")
    @im.handle_event("q")
    assert_equal("テキストカタカナ", @buffer.to_s)
  end

  def test_q_does_nothing_with_unconfirmed_romaji
    # Mirrors ddskk's skk-error "There remains a kana prefix": q refuses to
    # convert while a romaji prefix is still buffered.
    @im.handle_event("T")
    @im.handle_event("k") # buffered romaji prefix, no kana confirmed yet
    @im.handle_event("q")
    assert_equal("▽tk", @buffer.to_s)
    assert_equal("かな", @im.status)
  end

  def test_q_with_unconfirmed_romaji_paints_the_message_immediately
    # message() only updates the echo area's in-memory content; actually
    # painting it depends on Window.redisplay being called explicitly,
    # the same way other places in the codebase already do.
    #
    # message() alone can't tell whether the screen was actually redrawn
    # -- it sets Window.echo_area.message the same way either way -- so
    # this checks what actually reached the echo area's screen contents
    # instead.
    @im.handle_event("T")
    @im.handle_event("k")
    @im.handle_event("q")
    assert_equal("There remains a kana prefix", Window.echo_area.message)
    assert_equal(["There remains a kana prefix"], Window.echo_area.window.contents)
  end

  def test_q_does_nothing_while_starting_okurigana_consonant
    # Entering okurigana always leaves an unconfirmed romaji consonant
    # buffered until its first kana confirms, so q is refused here too.
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event("K") # starts okurigana with consonant "k"
    @im.handle_event("q")
    assert_equal("▽か*k", @buffer.to_s)
  end

  def test_q_in_katakana_mode_converts_yomi_to_hiragana_and_commits
    # The headword is already katakana while composing in katakana mode
    # (see "Converting phase in katakana mode" above), so toggling with q
    # here converts it to hiragana, not katakana.
    @im.handle_event("q") # switch to katakana mode
    %w[T e k i s u t o].each { |c| @im.handle_event(c) }
    assert_equal("▽テキスト", @buffer.to_s)
    @im.handle_event("q")
    assert_equal("てきすと", @buffer.to_s)
  end

  # --- Hankaku katakana mode ---

  def test_ctrl_q_switches_to_hankaku_katakana
    @im.handle_event("\C-q")
    assert_equal("半ｶﾅ", @im.status)
  end

  def test_ctrl_q_switches_back_to_hiragana
    @im.handle_event("\C-q")
    @im.handle_event("\C-q")
    assert_equal("かな", @im.status)
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
    assert_equal("SKK:", @im.status)
  end

  def test_l_passes_through_in_ascii
    @im.handle_event("l")
    result = @im.handle_event("l")
    assert_equal("l", result)
    assert_equal("SKK:", @im.status)
  end

  def test_L_passes_through_in_zenkaku
    @im.handle_event("L")
    result = @im.handle_event("L")
    assert_equal("Ｌ", result)
    assert_equal("全英", @im.status)
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
      assert_equal("かな", @im.status)
      assert_match(/\A▼/, @buffer.to_s)
    end

    def test_server_not_found
      @im.handle_event("A")
      @im.handle_event("x")
      @im.handle_event("x")
      @im.handle_event("x")
      @im.handle_event(" ")
      # No conversion: stays in converting phase
      assert_equal("かな", @im.status)
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
      assert_equal("かな", im.status)
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

  # --- z + ? zenkaku conversion ---

  def test_z_hyphen_inserts_wave_dash
    @im.handle_event("z")
    @im.handle_event("-")
    assert_equal("～", @buffer.to_s)
  end

  def test_z_period_inserts_ellipsis
    @im.handle_event("z")
    @im.handle_event(".")
    assert_equal("…", @buffer.to_s)
  end

  def test_z_slash_inserts_nakaguro
    @im.handle_event("z")
    @im.handle_event("/")
    assert_equal("・", @buffer.to_s)
  end

  def test_z_comma_inserts_two_dot_ellipsis
    @im.handle_event("z")
    @im.handle_event(",")
    assert_equal("‥", @buffer.to_s)
  end

  def test_z_open_paren_inserts_fullwidth_open_paren
    @im.handle_event("z")
    @im.handle_event("(")
    assert_equal("（", @buffer.to_s)
  end

  def test_z_close_paren_inserts_fullwidth_close_paren
    @im.handle_event("z")
    @im.handle_event(")")
    assert_equal("）", @buffer.to_s)
  end

  def test_z_open_bracket_inserts_double_open_bracket
    @im.handle_event("z")
    @im.handle_event("[")
    assert_equal("『", @buffer.to_s)
  end

  def test_z_close_bracket_inserts_double_close_bracket
    @im.handle_event("z")
    @im.handle_event("]")
    assert_equal("』", @buffer.to_s)
  end

  def test_z_h_inserts_left_arrow
    @im.handle_event("z")
    @im.handle_event("h")
    assert_equal("←", @buffer.to_s)
  end

  def test_z_j_inserts_down_arrow
    @im.handle_event("z")
    @im.handle_event("j")
    assert_equal("↓", @buffer.to_s)
  end

  def test_z_k_inserts_up_arrow
    @im.handle_event("z")
    @im.handle_event("k")
    assert_equal("↑", @buffer.to_s)
  end

  def test_z_l_inserts_right_arrow
    @im.handle_event("z")
    @im.handle_event("l")
    assert_equal("→", @buffer.to_s)
  end

  def test_z_uppercase_l_inserts_double_right_arrow
    @im.handle_event("z")
    @im.handle_event("L")
    assert_equal("⇒", @buffer.to_s)
  end

  def test_z_space_inserts_ideographic_space
    @im.handle_event("z")
    @im.handle_event(" ")
    assert_equal("　", @buffer.to_s)
  end

  def test_z_l_does_not_switch_to_ascii
    @im.handle_event("z")
    @im.handle_event("l")
    assert_equal("かな", @im.status)
  end

  def test_z_uppercase_l_does_not_switch_to_zenkaku_ascii
    @im.handle_event("z")
    @im.handle_event("L")
    assert_equal("かな", @im.status)
  end

  # --- Status display ---

  def test_status_hiragana
    assert_equal("かな", @im.status)
  end

  def test_status_katakana
    @im.handle_event("q")
    assert_equal("カナ", @im.status)
  end

  def test_status_ascii
    @im.handle_event("l")
    assert_equal("SKK:", @im.status)
  end

  def test_status_zenkaku
    @im.handle_event("L")
    assert_equal("全英", @im.status)
  end

  def test_status_converting
    @im.handle_event("K")
    assert_equal("かな", @im.status)
  end

  def test_status_selecting
    @im.handle_event("K")
    @im.handle_event("a")
    @im.handle_event(" ")
    assert_equal("かな", @im.status)
  end
end
