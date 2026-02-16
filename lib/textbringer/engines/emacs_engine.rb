# frozen_string_literal: true

module Textbringer
  class EmacsEngine < Engine
    register :emacs

    class << self
      def global_keymap = GLOBAL_MAP

      def minibuffer_keymap = MINIBUFFER_LOCAL_MAP

      def supports_multi_stroke? = true

      def supports_prefix_arg? = true

      def supports_keyboard_macros? = true

      def buffer_features = [:kill_ring, :mark_ring, :global_mark_ring, :input_methods]

      def selection_model = :emacs_mark

      def clipboard_model = :kill_ring
    end
  end
end
