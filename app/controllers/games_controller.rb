class GamesController < ApplicationController
  before_action :set_game, only: %i[ show roll_dice move reset ]
  skip_before_action :verify_authenticity_token, only: [:move]

  def roll_dice
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
    state.apply_move!(from:, to:)

    state.apply_to_record!(@game)
    @game.save!

    flash.now[:alert] = state.flash_alert if state.flash_alert.present?
    render_game_update
  rescue Backgammon::Error => e
    render_domain_error(e)
  rescue StandardError => e
    render_server_error(e, tag: "MOVE")
  end

  def reset
    state = @game.domain_state
    state.reset!

    state.apply_to_record!(@game)
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
    [
      turbo_stream.replace("game_area", partial: "board/game_board", locals: { game: @game }),
      turbo_stream.replace("flash-message", partial: "board/flash_message")
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
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("flash-message", partial: "board/flash_message"), status: }
      format.json { render json: { error: flash[:alert].to_s }, status: }
      format.html { redirect_to root_path, alert: flash[:alert].to_s }
      format.any { render turbo_stream: turbo_stream.replace("flash-message", partial: "board/flash_message"), status: }
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
end