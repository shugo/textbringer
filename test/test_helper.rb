require "simplecov"
require "test/unit"

SimpleCov.start

require "textbringer"

null_controller = Object.new
def null_controller.method_missing(mid, *args)
  nil
end
Textbringer::Controller.current = null_controller
