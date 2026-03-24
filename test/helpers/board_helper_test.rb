require "test_helper"

class BoardHelperTest < ActionView::TestCase
  test "formats history labels with international point numbers" do
    assert_equal "24", history_point_label(11, "white")
    assert_equal "23", history_point_label(10, "white")
    assert_equal "24", history_point_label(23, "black")
    assert_equal "off", history_point_label(-1, "white")
    assert_equal "24→23", history_move_label({ "from" => 11, "to" => 10, "color" => "white" })
  end
end
