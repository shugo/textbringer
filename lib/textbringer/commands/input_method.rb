module Textbringer
  module Commands
    define_command(:toggle_input_method,
                   doc: "Toggel input method") do
      Buffer.current.toggle_input_method
    end
  end
end
