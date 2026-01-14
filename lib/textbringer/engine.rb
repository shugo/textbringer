# frozen_string_literal: true

module Textbringer
  class Engine
    @registry = {}

    class << self
      # Registry for engine lookup by symbol
      def register(name)
        Engine.instance_variable_get(:@registry)[name] = self
        @engine_name = name
      end

      def [](name)
        Engine.instance_variable_get(:@registry)[name]
      end

      # Engine identification
      attr_reader :engine_name

      # Keymap configuration
      def global_keymap = nil
      def minibuffer_keymap = nil

      # Feature support flags
      def supports_multi_stroke? = false
      def supports_prefix_arg? = false
      def supports_keyboard_macros? = false

      # Buffer features this engine uses
      # Possible values: :kill_ring, :mark_ring, :global_mark_ring, :input_methods
      def buffer_features = []

      # Selection model: :emacs_mark or :shift_select
      def selection_model = :emacs_mark

      # Clipboard model: :kill_ring or :simple
      def clipboard_model = :kill_ring

      # Process key event and return command
      # Returns: Symbol (command), Keymap (partial match), or nil (undefined)
      def process_key_event(controller, key_sequence)
        controller.overriding_map&.lookup(key_sequence) ||
          Buffer.current&.keymap&.lookup(key_sequence) ||
          global_keymap&.lookup(key_sequence)
      end

      # Called when engine is activated
      def setup; end
    end
  end
end
