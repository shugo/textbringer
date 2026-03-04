module Textbringer
  module Elisp
    module Primitives
      def self.register!
        r = Runtime

        # --- Arithmetic ---
        r.defun(:"+") { |*args| args.reduce(0, :+) }
        r.defun(:"-") { |first, *rest| rest.empty? ? -first : rest.reduce(first, :-) }
        r.defun(:"*") { |*args| args.reduce(1, :*) }
        r.defun(:"/") do |first, *rest|
          rest.reduce(first) do |a, b|
            if a.is_a?(Integer) && b.is_a?(Integer)
              a / b
            else
              a.to_f / b
            end
          end
        end
        r.defun(:"%") { |a, b| a % b }
        r.defun(:"1+") { |n| n + 1 }
        r.defun(:"1-") { |n| n - 1 }
        r.defun(:"max") { |*args| args.max }
        r.defun(:"min") { |*args| args.min }
        r.defun(:"abs") { |n| n.abs }

        r.function_table[:"el_one_plus"] = r.function_table[:"1+"]
        r.function_table[:"el_one_minus"] = r.function_table[:"1-"]

        # --- Comparison ---
        r.defun(:"=") { |a, b| a == b ? true : nil }
        r.defun(:"/=") { |a, b| a != b ? true : nil }
        r.defun(:"<") { |a, b| a < b ? true : nil }
        r.defun(:">") { |a, b| a > b ? true : nil }
        r.defun(:"<=") { |a, b| a <= b ? true : nil }
        r.defun(:">=") { |a, b| a >= b ? true : nil }
        r.defun(:"eq") { |a, b| r.el_eq(a, b) }
        r.defun(:"eql") { |a, b| r.el_eql(a, b) }
        r.defun(:"equal") { |a, b| r.el_equal(a, b) }

        # --- List operations ---
        r.defun(:"car") { |obj| r.car(obj) }
        r.defun(:"cdr") { |obj| r.cdr(obj) }
        r.defun(:"cons") { |a, b| r.cons(a, b) }
        r.defun(:"list") { |*args| r.list(*args) }
        r.defun(:"append") { |*args| r.el_append(*args) }
        r.defun(:"nth") { |n, list| r.el_nth(n, list) }
        r.defun(:"nthcdr") { |n, list| r.el_nthcdr(n, list) }
        r.defun(:"length") { |obj| r.el_length(obj) }
        r.defun(:"reverse") { |list| r.el_reverse(list) }
        r.defun(:"mapcar") do |func, list|
          result = []
          current = list
          while current.is_a?(Runtime::Cons)
            result << r.funcall(func, current.car)
            current = current.cdr
          end
          r.list(*result)
        end
        r.defun(:"mapc") do |func, list|
          current = list
          while current.is_a?(Runtime::Cons)
            r.funcall(func, current.car)
            current = current.cdr
          end
          list
        end
        r.defun(:"member") do |elt, list|
          result = nil
          current = list
          while current.is_a?(Runtime::Cons)
            if current.car == elt
              result = current
              break
            end
            current = current.cdr
          end
          result
        end
        r.defun(:"assoc") do |key, alist|
          result = nil
          current = alist
          while current.is_a?(Runtime::Cons)
            pair = current.car
            if pair.is_a?(Runtime::Cons) && pair.car == key
              result = pair
              break
            end
            current = current.cdr
          end
          result
        end

        # --- String operations ---
        r.defun(:"string=") { |a, b| a == b ? true : nil }
        r.defun(:"string<") { |a, b| a < b ? true : nil }
        r.defun(:"concat") { |*args| args.map(&:to_s).join }
        r.defun(:"substring") do |str, from, to = nil|
          to ? str[from...to] : str[from..]
        end
        r.defun(:"string-match") do |regexp, str, start = 0|
          re = Regexp.new(regexp)
          m = re.match(str, start)
          m ? m.begin(0) : nil
        end
        r.defun(:"format") { |fmt, *args| format(fmt.gsub("%s", "%s").gsub("%d", "%d"), *args) }
        r.defun(:"upcase") { |s| s.upcase }
        r.defun(:"downcase") { |s| s.downcase }
        r.defun(:"number-to-string") { |n| n.to_s }
        r.defun(:"string-to-number") { |s| s.include?(".") ? s.to_f : s.to_i }
        r.defun(:"symbol-name") { |s| s.to_s }
        r.defun(:"intern") { |s| s.to_sym }

        # --- Type predicates ---
        r.defun(:"null") { |obj| obj.nil? ? true : nil }
        r.defun(:"listp") { |obj| (obj.nil? || obj.is_a?(Runtime::Cons)) ? true : nil }
        r.defun(:"consp") { |obj| obj.is_a?(Runtime::Cons) ? true : nil }
        r.defun(:"atom") { |obj| obj.is_a?(Runtime::Cons) ? nil : true }
        r.defun(:"stringp") { |obj| obj.is_a?(::String) ? true : nil }
        r.defun(:"numberp") { |obj| obj.is_a?(Numeric) ? true : nil }
        r.defun(:"integerp") { |obj| obj.is_a?(Integer) ? true : nil }
        r.defun(:"floatp") { |obj| obj.is_a?(Float) ? true : nil }
        r.defun(:"symbolp") { |obj| obj.is_a?(::Symbol) ? true : nil }
        r.defun(:"functionp") { |obj| obj.is_a?(Proc) ? true : nil }
        r.defun(:"not") { |obj| r.el_not(obj) }
        r.defun(:"type-of") do |obj|
          case obj
          when Integer then :integer
          when Float then :float
          when ::String then :string
          when ::Symbol then :symbol
          when Runtime::Cons then :cons
          when NilClass then :symbol
          when Proc then :function
          when TrueClass then :symbol
          else :unknown
          end
        end

        # --- Buffer operations ---
        r.defun(:"point") { Buffer.current.point }
        r.defun(:"point-min") { Buffer.current.point_min }
        r.defun(:"point-max") { Buffer.current.point_max }
        r.defun(:"goto-char") { |pos| Buffer.current.goto_char(pos) }
        r.defun(:"forward-char") { |n = 1| Buffer.current.forward_char(n) }
        r.defun(:"backward-char") { |n = 1| Buffer.current.backward_char(n) }
        r.defun(:"beginning-of-line") { Buffer.current.beginning_of_line }
        r.defun(:"end-of-line") { Buffer.current.end_of_line }
        r.defun(:"insert") { |*args| args.each { |s| Buffer.current.insert(s.to_s) } }
        r.defun(:"delete-char") { |n = 1| Buffer.current.delete_char(n) }
        r.defun(:"delete-region") { |start, stop| Buffer.current.delete_region(start, stop) }
        r.defun(:"buffer-substring") { |start, stop| Buffer.current.substring(start, stop) }
        r.defun(:"search-forward") do |str, bound = nil, noerror = nil|
          Buffer.current.search_forward(str, bound: bound)
        rescue SearchError
          raise unless r.truthy?(noerror)
          nil
        end
        r.defun(:"re-search-forward") do |regexp, bound = nil, noerror = nil|
          Buffer.current.re_search_forward(regexp, bound: bound)
        rescue SearchError
          raise unless r.truthy?(noerror)
          nil
        end
        r.defun(:"looking-at") do |regexp|
          Buffer.current.looking_at?(Regexp.new(regexp)) ? true : nil
        end
        r.defun(:"match-beginning") { |n| Buffer.current.match_beginning(n) }
        r.defun(:"match-end") { |n| Buffer.current.match_end(n) }
        r.defun(:"match-string") { |n| Buffer.current.match_string(n) }
        r.defun(:"replace-match") { |newtext| Buffer.current.replace_match(newtext) }
        r.defun(:"current-buffer") { Buffer.current }
        r.defun(:"buffer-name") { |buf = nil| (buf || Buffer.current).name }
        r.defun(:"set-buffer") { |buf| Buffer.current = buf if buf.is_a?(Buffer) }

        # --- Misc ---
        r.defun(:"message") do |fmt, *args|
          msg = if args.empty?
                  fmt.to_s
                else
                  format(fmt, *args)
                end
          if defined?(Textbringer::Commands)
            Textbringer::Commands.message(msg)
          end
          msg
        end

        r.defun(:"apply") do |func, *args|
          # Last arg should be a list
          if args.last.is_a?(Runtime::Cons)
            flat_args = args[0...-1] + args.last.to_list
          elsif args.last.nil?
            flat_args = args[0...-1]
          else
            flat_args = args
          end
          r.funcall(func, *flat_args)
        end

        r.defun(:"funcall") do |func, *args|
          r.funcall(func, *args)
        end

        r.defun(:"provide") { |feature| r.provide(feature) }
        r.defun(:"featurep") { |feature| r.featurep?(feature) }
        r.defun(:"require") do |feature|
          unless r.featurep?(feature)
            Textbringer::Elisp.load_feature(feature)
          end
        end
      end
    end
  end
end
