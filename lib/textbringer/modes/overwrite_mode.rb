module Textbringer
  class OverwriteMode < MinorMode
    self.mode_name = "Ovwrt"

    POST_INSERT_HOOK = -> {
      buffer = Buffer.current
      s = Controller.current.last_key * number_prefix_arg
      begin
        buffer.delete_char(s.size)
      rescue RangeError
        buffer.save_excursion do
          pos = buffer.point
          buffer.end_of_buffer
          buffer.delete_region(pos, buffer.point)
        end
      end
    }

    def enable
      add_hook(:post_self_insert_hook, POST_INSERT_HOOK, local: true)
    end

    def disable
      remove_hook(:post_self_insert_hook, POST_INSERT_HOOK, local: true)
    end
  end
end
