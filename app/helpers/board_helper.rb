module BoardHelper
  def history_point_label(index, color)
    idx = index.to_i
    return "off" if idx.negative?

    path = Backgammon::Rules.path_for(color)
    point_index = path.index(idx)
    return "?" if point_index.nil?

    (24 - point_index).to_s
  end

  def history_move_label(entry)
    color = entry["color"] == "black" ? "black" : "white"
    from_label = history_point_label(entry["from"], color)
    to_label = history_point_label(entry["to"], color)
    "#{from_label}\u2192#{to_label}"
  end
end
