class BoardController < ApplicationController
  def index
    @game = Game.last || Game.create
  end
end
