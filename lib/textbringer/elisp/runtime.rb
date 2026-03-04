module Textbringer
  module Elisp
    module Runtime
      class ElispError < StandardError; end

      # Cons cell for proper Elisp lists
      class Cons
        attr_accessor :car, :cdr

        def initialize(car, cdr)
          @car = car
          @cdr = cdr
        end

        def to_list
          result = []
          current = self
          while current.is_a?(Cons)
            result << current.car
            current = current.cdr
          end
          result
        end

        def ==(other)
          other.is_a?(Cons) && car == other.car && cdr == other.cdr
        end

        def inspect
          if cdr.nil? || cdr.is_a?(Cons)
            "(#{list_inspect})"
          else
            "(#{car.inspect} . #{cdr.inspect})"
          end
        end

        private

        def list_inspect
          result = [car.inspect]
          current = cdr
          while current.is_a?(Cons)
            result << current.car.inspect
            current = current.cdr
          end
          result << ". #{current.inspect}" unless current.nil?
          result.join(" ")
        end
      end

      class << self
        # Dynamic variable stacks
        def var_stacks
          @var_stacks ||= {}
        end

        # Function table
        def function_table
          @function_table ||= {}
        end

        # Macro table
        def macro_table
          @macro_table ||= {}
        end

        # Feature set
        def features
          @features ||= Set.new
        end

        # Load path
        def load_path
          @load_path ||= []
        end

        # --- Variable operations ---

        def get_var(name)
          stack = var_stacks[name]
          if stack && !stack.empty?
            stack.last
          else
            nil
          end
        end

        def set_var(name, value)
          stack = var_stacks[name]
          if stack && !stack.empty?
            stack[-1] = value
          else
            var_stacks[name] ||= []
            var_stacks[name].push(value)
          end
          value
        end

        def defvar(name, value, _doc = nil)
          unless var_stacks[name] && !var_stacks[name].empty?
            var_stacks[name] = [value]
          end
          name
        end

        def with_dynamic_bindings(bindings, &block)
          bindings.each do |name, value|
            var_stacks[name] ||= []
            var_stacks[name].push(value)
          end
          begin
            block.call
          ensure
            bindings.each_key do |name|
              var_stacks[name].pop
            end
          end
        end

        def with_dynamic_binding(name, value, &block)
          with_dynamic_bindings({ name => value }, &block)
        end

        # --- Function operations ---

        def defun(name, &block)
          function_table[name] = block
          name
        end

        def defun_interactive(name, spec, doc = nil, &block)
          function_table[name] = block
          # Register as a Textbringer command
          define_command(name, doc: doc || "Elisp command: #{name}") do
            args = Runtime.parse_interactive_spec(spec)
            Runtime.funcall(name, *args)
          end
          name
        end

        def funcall(name, *args)
          if name.is_a?(Proc)
            return name.call(*args)
          end
          func = function_table[name]
          raise ElispError, "void function: #{name}" unless func
          func.call(*args)
        end

        def function_ref(name)
          function_table[name]
        end

        def make_lambda(&block)
          block
        end

        # --- Truthiness (Elisp semantics) ---

        def truthy?(val)
          val != nil && val != false
        end

        # --- List operations ---

        def list(*args)
          return nil if args.empty?
          result = nil
          args.reverse_each do |a|
            result = Cons.new(a, result)
          end
          result
        end

        def cons(car, cdr)
          Cons.new(car, cdr)
        end

        def car(obj)
          return nil if obj.nil?
          raise ElispError, "wrong type argument: listp, #{obj.inspect}" unless obj.is_a?(Cons)
          obj.car
        end

        def cdr(obj)
          return nil if obj.nil?
          raise ElispError, "wrong type argument: listp, #{obj.inspect}" unless obj.is_a?(Cons)
          obj.cdr
        end

        def el_length(obj)
          return 0 if obj.nil?
          return obj.length if obj.is_a?(::String) || obj.is_a?(::Array)
          count = 0
          current = obj
          while current.is_a?(Cons)
            count += 1
            current = current.cdr
          end
          count
        end

        def el_nth(n, list)
          current = list
          n.times do
            return nil unless current.is_a?(Cons)
            current = current.cdr
          end
          current.is_a?(Cons) ? current.car : nil
        end

        def el_nthcdr(n, list)
          current = list
          n.times do
            return nil unless current.is_a?(Cons)
            current = current.cdr
          end
          current
        end

        def el_append(*lists)
          return nil if lists.empty?
          result_elements = []
          lists[0...-1].each do |l|
            current = l
            while current.is_a?(Cons)
              result_elements << current.car
              current = current.cdr
            end
          end
          tail = lists.last
          result_elements.reverse_each do |elem|
            tail = Cons.new(elem, tail)
          end
          tail
        end

        def el_reverse(list)
          result = nil
          current = list
          while current.is_a?(Cons)
            result = Cons.new(current.car, result)
            current = current.cdr
          end
          result
        end

        # --- Short-circuit logic ---

        def el_and(*lambdas)
          result = true
          lambdas.each do |l|
            result = l.call
            return nil unless truthy?(result)
          end
          result
        end

        def el_or(*lambdas)
          lambdas.each do |l|
            result = l.call
            return result if truthy?(result)
          end
          nil
        end

        # --- Catch/throw ---

        def catch_tag(tag)
          :"__elisp_catch_#{tag}"
        end

        # --- Arithmetic helpers ---

        def el_plus(*args)
          args.reduce(0, :+)
        end

        def el_minus(first = nil, *rest)
          return 0 if first.nil?
          return -first if rest.empty?
          rest.reduce(first, :-)
        end

        def el_multiply(*args)
          args.reduce(1, :*)
        end

        def el_divide(first, *rest)
          return first if rest.empty?
          rest.reduce(first) do |a, b|
            if a.is_a?(Integer) && b.is_a?(Integer)
              a / b
            else
              a.to_f / b
            end
          end
        end

        def el_mod(a, b)
          a % b
        end

        def el_one_plus(n)
          n + 1
        end

        def el_one_minus(n)
          n - 1
        end

        # --- Comparison helpers ---

        def el_eq(a, b)
          a.equal?(b) || (a.is_a?(::Symbol) && a == b) ||
            (a.is_a?(Integer) && a == b) ? true : nil
        end

        def el_eql(a, b)
          a.eql?(b) ? true : nil
        end

        def el_equal(a, b)
          a == b ? true : nil
        end

        def el_num_eq(a, b)
          a == b ? true : nil
        end

        def el_lt(a, b)
          a < b ? true : nil
        end

        def el_gt(a, b)
          a > b ? true : nil
        end

        def el_le(a, b)
          a <= b ? true : nil
        end

        def el_ge(a, b)
          a >= b ? true : nil
        end

        def el_not(val)
          truthy?(val) ? nil : true
        end

        # --- Feature system ---

        def provide(feature)
          features.add(feature.to_sym)
          feature
        end

        def featurep?(feature)
          features.include?(feature.to_sym) ? true : nil
        end

        # --- Interactive spec parsing ---

        def parse_interactive_spec(spec)
          return [] if spec.nil? || spec.empty?
          args = []
          i = 0
          while i < spec.length
            code = spec[i]
            i += 1
            case code
            when "s"
              prompt = extract_prompt(spec, i)
              i += prompt.length
              args << read_from_minibuffer(prompt)
            when "n"
              prompt = extract_prompt(spec, i)
              i += prompt.length
              args << read_from_minibuffer(prompt).to_i
            when "r"
              b = Textbringer::Buffer.current
              args << [b.point, b.mark].min
              args << [b.point, b.mark].max
            when "p"
              args << (current_prefix_arg || 1)
            when "\n"
              # separator, skip
            else
              prompt = extract_prompt(spec, i)
              i += prompt.length
            end
          end
          args
        end

        def reset!
          @var_stacks = {}
          @function_table = {}
          @macro_table = {}
          @features = Set.new
        end

        private

        def extract_prompt(spec, start)
          idx = spec.index("\n", start) || spec.length
          spec[start...idx]
        end
      end
    end
  end
end
