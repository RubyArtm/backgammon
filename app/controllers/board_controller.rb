class BoardController < ApplicationController
  def index
    @game = current_game
  end

  private

  def current_game
    if session[:game_id].present?
      existing = Game.find_by(id: session[:game_id])
      return existing if existing
    end

    create_new_game
  end

  def create_new_game
    game = Game.create
    session[:game_id] = game.id
    game
  end
end
