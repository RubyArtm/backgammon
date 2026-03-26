class BoardController < ApplicationController
  def index
    @game = current_game
    replay_step_param = params[:replay_step]

    if replay_step_param.present?
      @display_game, @replay_step, @replay_total = @game.replay_view(replay_step_param)
      @replay_mode = true
    else
      @display_game = @game
      @replay_total = @game.move_history_entries.size
      @replay_step = @replay_total
      @replay_mode = false
    end
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
    game = Game.create!
    session[:game_id] = game.id
    game
  end
end
