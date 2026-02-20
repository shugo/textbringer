require_relative "../../test_helper"

class TestLSPCommands < Textbringer::TestCase
  def test_lsp_completion_context_invoked_with_prefix
    # When there is a prefix typed, always use Invoked (triggerKind 1)
    context = lsp_completion_context("fo", ["."], ".")
    assert_equal({ triggerKind: 1 }, context)
  end

  def test_lsp_completion_context_invoked_no_trigger_char
    # Empty prefix but char before start is not a trigger character
    context = lsp_completion_context("", ["."], "x")
    assert_equal({ triggerKind: 1 }, context)
  end

  def test_lsp_completion_context_invoked_no_trigger_chars_configured
    # No trigger characters configured on the server
    context = lsp_completion_context("", [], ".")
    assert_equal({ triggerKind: 1 }, context)
  end

  def test_lsp_completion_context_trigger_character
    # Empty prefix and char before start is a trigger character → TriggerCharacter (triggerKind 2)
    context = lsp_completion_context("", ["."], ".")
    assert_equal({ triggerKind: 2, triggerCharacter: "." }, context)
  end

  def test_lsp_completion_context_trigger_character_colon
    # Empty prefix and :: trigger
    context = lsp_completion_context("", [":", "::", "."], ":")
    assert_equal({ triggerKind: 2, triggerCharacter: ":" }, context)
  end

  def test_lsp_completion_context_prefix_overrides_trigger_char
    # Even when char before start is a trigger char, prefix present → Invoked
    context = lsp_completion_context("bo", ["."], ".")
    assert_equal({ triggerKind: 1 }, context)
  end

  # lsp_text_document_sync_kind

  def test_sync_kind_integer_none
    assert_equal(0, lsp_text_document_sync_kind("textDocumentSync" => 0))
  end

  def test_sync_kind_integer_full
    assert_equal(1, lsp_text_document_sync_kind("textDocumentSync" => 1))
  end

  def test_sync_kind_integer_incremental
    assert_equal(2, lsp_text_document_sync_kind("textDocumentSync" => 2))
  end

  def test_sync_kind_hash_full
    assert_equal(1, lsp_text_document_sync_kind("textDocumentSync" => { "change" => 1 }))
  end

  def test_sync_kind_hash_incremental
    assert_equal(2, lsp_text_document_sync_kind("textDocumentSync" => { "change" => 2 }))
  end

  def test_sync_kind_hash_without_change_key_defaults_to_incremental
    # Hash present but no "change" key → default to Incremental (2)
    assert_equal(2, lsp_text_document_sync_kind("textDocumentSync" => { "openClose" => true }))
  end

  def test_sync_kind_missing_capability_defaults_to_incremental
    assert_equal(2, lsp_text_document_sync_kind({}))
  end
end
