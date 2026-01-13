Rails.application.routes.draw do

  get "board/index"
  get "up" => "rails/health#show", as: :rails_health_check

  resources :games do
    member do
      post :roll_dice
      post :move
      post :reset
    end
  end

  root "board#index"
end
