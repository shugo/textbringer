# frozen_string_literal: true

module Textbringer
  class EditorError < StandardError
  end

  class SearchError < EditorError
  end

  class ReadOnlyError < EditorError
  end

  class Quit < EditorError
    def initialize
      super("Quit")
    end
  end
end
