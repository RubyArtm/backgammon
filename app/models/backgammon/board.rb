module Backgammon
  class Board
    POINTS_COUNT = 24

    def self.initial
      points = Array.new(POINTS_COUNT) { { color: nil, count: 0 } }
      points[11] = { color: "white", count: 15 }
      points[23] = { color: "black", count: 15 }
      new(points)
    end

    def self.from_json(value)
      raw = Array(value)
      points = raw.map do |p|
        h = p.is_a?(Hash) ? p : {}
        {
          color: h["color"] || h[:color],
          count: (h["count"] || h[:count] || 0).to_i
        }
      end

      new(points)
    end

    def initialize(points)
      @points = normalize(points)
    end

    def to_json
      @points.map { |p| { color: p[:color], count: p[:count] } }
    end

    def point(index)
      @points.fetch(index)
    end

    def color_at(index) = point(index)[:color]
    def count_at(index) = point(index)[:count]

    def dup
      self.class.new(@points.map(&:dup))
    end

    def decrement!(index)
      p = point(index)
      p[:count] -= 1
      if p[:count] <= 0
        p[:count] = 0
        p[:color] = nil
      end
    end

    def increment!(index, color:)
      p = point(index)
      p[:count] += 1
      p[:color] = color
    end

    def each_index
      return enum_for(:each_index) unless block_given?
      0.upto(POINTS_COUNT - 1) { |i| yield i }
    end

    private

    def normalize(points)
      arr = Array(points).map do |p|
        h = p.is_a?(Hash) ? p : {}
        { color: h[:color], count: h[:count].to_i }
      end

      if arr.size != POINTS_COUNT
        raise Backgammon::Error, "Invalid board size: #{arr.size} (expected #{POINTS_COUNT})"
      end

      arr
    end
  end
end