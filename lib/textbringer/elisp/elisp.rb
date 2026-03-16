require_relative "ast"
require_relative "reader"
require_relative "runtime"
require_relative "compiler"
require_relative "primitives"

module Textbringer
  module Elisp
    class << self
      def init
        return if @initialized
        Primitives.register!
        @initialized = true
      end

      def eval_string(source, filename: "(elisp)")
        init
        reader = Reader.new(source, filename: filename)
        forms = reader.read_all
        compiler = Compiler.new
        ruby_source = compiler.compile(forms, filename: filename)
        iseq = RubyVM::InstructionSequence.compile(ruby_source, filename)
        iseq.eval
      end

      def load_file(path)
        source = File.read(path, encoding: "utf-8")
        eval_string(source, filename: path)
      end

      def load_feature(feature)
        name = feature.to_s
        name = name + ".el" unless name.end_with?(".el")

        Runtime.load_path.each do |dir|
          path = File.join(dir, name)
          if File.exist?(path)
            load_file(path)
            return true
          end
        end

        raise Runtime::ElispError, "Cannot find feature: #{feature}"
      end

      def reset!
        Runtime.reset!
        @initialized = false
      end
    end
  end
end
