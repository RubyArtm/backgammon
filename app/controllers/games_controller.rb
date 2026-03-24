class GamesController < ApplicationController
  before_action :set_game, only: %i[ show edit update destroy roll_dice move undo_move reset ]

  def index
    @games = Game.all
  end

  def show; end

  def new
    @game = Game.new
  end

  def edit; end

  def create
    @game = Game.new(game_params)

    respond_to do |format|
      if @game.save
        format.html { redirect_to @game, notice: "Game was successfully created." }
        format.json { render :show, status: :created, location: @game }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @game.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @game.update(game_params)
        format.html { redirect_to @game, notice: "Game was successfully updated." }
        format.json { render :show, status: :ok, location: @game }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @game.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @game.destroy!

    respond_to do |format|
      format.html { redirect_to games_path, status: :see_other, notice: "Game was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def roll_dice
    @game.clear_undo_history!
    state = @game.domain_state
    state.roll_dice!

    state.apply_to_record!(@game)
    @game.save!

    flash.now[:alert] = state.flash_alert if state.flash_alert.present?
    render_game_update
  rescue Backgammon::Error => e
    render_domain_error(e)
  rescue StandardError => e
    render_server_error(e, tag: "ROLL_DICE")
  end

  def move
    from = params.require(:from_index).to_i
    to   = params.require(:to_index).to_i

    state = @game.domain_state
    previous_state = state.snapshot
    state.apply_move!(from:, to:)

    state.apply_to_record!(@game)
    @game.push_undo_snapshot!(previous_state)
    @game.append_move_history!(
      {
        "from" => from,
        "to" => to,
        "color" => previous_state["current_turn"].to_i.zero? ? "white" : "black",
        "die" => state.last_used_die.to_i,
        "before" => previous_state,
        "after" => state.snapshot,
        "at" => Time.current.iso8601
      }
    )
    @game.save!

    flash.now[:alert] = state.flash_alert if state.flash_alert.present?
    render_game_update
  rescue Backgammon::Error => e
    render_domain_error(e)
  rescue StandardError => e
    render_server_error(e, tag: "MOVE")
  end

  def undo_move
    snapshot = @game.pop_undo_snapshot!
    unless snapshot
      flash.now[:alert] = "Undo is available only before opponent rolls the dice."
      return render_flash_stream(status: :unprocessable_entity)
    end

    state = @game.domain_state
    state.restore_from_snapshot!(snapshot)
    state.apply_to_record!(@game)
    @game.save!

    render_game_update
  rescue Backgammon::Error => e
    render_domain_error(e)
  rescue StandardError => e
    render_server_error(e, tag: "UNDO_MOVE")
  end

  def reset
    state = @game.domain_state
    state.reset!(preserve_stats: ActiveModel::Type::Boolean.new.cast(params[:preserve_stats]))

    state.apply_to_record!(@game)
    @game.clear_undo_history!
    @game.clear_move_history!
    @game.save!

    render_game_update
  rescue Backgammon::Error => e
    render_domain_error(e)
  rescue StandardError => e
    render_server_error(e, tag: "RESET")
  end

  private

  def set_game
    @game = Game.find(params[:id])
  end

  def game_update_streams
    flash_message = flash[:alert].presence || flash[:notice].presence

    [
      turbo_stream.replace(
        "game_area",
        partial: "board/game_board",
        locals: {
          game: @game,
          replay_mode: false,
          replay_step: @game.move_history_entries.size,
          replay_total: @game.move_history_entries.size
        }
      ),
      turbo_stream.replace(
        "flash-message",
        partial: "board/flash_message",
        locals: { message: flash_message }
      )
    ]
  end

  def render_game_update
    respond_to do |format|
      format.turbo_stream { render turbo_stream: game_update_streams }
      format.json { render json: { status: "ok" } }
      format.html { redirect_to root_path }
      format.any { render turbo_stream: game_update_streams }
    end
  end

  def render_flash_stream(status:)
    flash_message = flash[:alert].presence || flash[:notice].presence

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "flash-message",
          partial: "board/flash_message",
          locals: { message: flash_message }
        ), status:
      end
      format.json { render json: { error: flash[:alert].to_s }, status: }
      format.html { redirect_to root_path, alert: flash[:alert].to_s }
      format.any do
        render turbo_stream: turbo_stream.replace(
          "flash-message",
          partial: "board/flash_message",
          locals: { message: flash_message }
        ), status:
      end
    end
  end

  def render_domain_error(error)
    flash.now[:alert] = error.message
    render_flash_stream(status: error.http_status)
  end

  def render_server_error(error, tag:)
    Rails.logger.error("[#{tag} 500] #{error.class}: #{error.message}\n#{error.backtrace&.first(30)&.join("\n")}")
    flash.now[:alert] = "Server error. See Rails log."
    render_flash_stream(status: :internal_server_error)
  end

  def game_params
    params.fetch(:game, {}).permit(:status, :current_turn, :dice_1, :dice_2, :board_state)
  end
end
