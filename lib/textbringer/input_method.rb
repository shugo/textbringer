module Textbringer
  class InputMethod
    extend Commands
    include Commands

    def self.find(name)
      class_name = name.split(/_/).map(&:capitalize).join + "InputMethod"
      Textbringer.const_get(class_name).new
    rescue NameError
      "No such input method: #{name}"
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
      raise EditorError, "subclass must override InputMethod#handle"
    end
  end
end
