module Textbringer
  class InputMethod
    extend Commands
    include Commands

    @@list = []

    def self.inherited(subclass)
      name = subclass.name.sub(/Textbringer::/, "").sub(/InputMethod/, "").
        gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').gsub(/([a-z\d])([A-Z])/, '\1_\2').
        downcase
      @@list.push(name)
    end

    def self.list
      @@list
    end

    def self.find(name)
      class_name = name.split(/_/).map(&:capitalize).join + "InputMethod"
      Textbringer.const_get(class_name).new
    rescue NameError
      raise EditorError, "No such input method: #{name}"
    end

    def initialize
      @enabled = false
      @skip_next_event = false
    end

    def toggle
      @enabled = !@enabled
    end

    def disable
      @enabled = false
    end

    def enabled?
      @enabled
    end

    def filter_event(event)
      if @enabled
        if event == "\e"
          @skip_next_event = true
          event
        elsif @skip_next_event
          @skip_next_event = false
          event
        else
          handle_event(event)
        end
      else
        event
      end
    end

    def handle_event(event)
      raise EditorError, "subclass must override InputMethod#handle_event"
    end

    def with_target_buffer(&block)
      if isearch_mode?
        @isearch_buffer ||= Buffer.new
        if @isearch_buffer.to_s != ISEARCH_STATUS[:string]
          @isearch_buffer.replace(ISEARCH_STATUS[:string])
        end
        block.call(@isearch_buffer)
        ISEARCH_STATUS[:string] = @isearch_buffer.to_s
        if Buffer.current != Buffer.minibuffer
          message(isearch_prompt + ISEARCH_STATUS[:string], log: false)
          Window.redisplay
        end
      else
        block.call(Buffer.current)
      end
    end
  end
end
