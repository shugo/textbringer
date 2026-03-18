module Textbringer
  module Commands
    define_command(:gamegrid_show_scores,
                   doc: "Display high scores for a game.") do
      |game_name = read_from_minibuffer("Game name: ")|
      scores = Gamegrid.load_scores(game_name)
      buffer = Buffer.find_or_new("*Scores*", undo_limit: 0)
      buffer.read_only_edit do
        buffer.clear
        buffer.insert("High Scores for #{game_name}\n")
        buffer.insert("=" * 40 + "\n\n")
        if scores.empty?
          buffer.insert("No scores recorded.\n")
        else
          scores.each_with_index do |entry, i|
            buffer.insert(
              "#{i + 1}. #{entry[:score]}  #{entry[:player]}  #{entry[:time]}\n"
            )
          end
        end
      end
      switch_to_buffer(buffer)
    end
  end
end
