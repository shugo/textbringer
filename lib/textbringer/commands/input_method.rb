module Textbringer
  module Commands
    define_command(:toggle_input_method,
                   doc: "Toggel input method.") do |name = nil|
      if name.nil? && current_prefix_arg
        name = read_input_method_name("Input method: ")
      end
      Buffer.current.toggle_input_method(name)
    end

    def read_input_method_name(prompt, default: CONFIG[:default_input_method])
      f = ->(s) {
        complete_for_minibuffer(s.tr("-", "_"), InputMethod.list)
      }
      read_from_minibuffer(prompt, completion_proc: f, default: default)
    end
  end
end
