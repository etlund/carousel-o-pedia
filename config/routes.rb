Rails.application.routes.draw do
  root "carousels#index"

  concern :historical do
    get :history, on: :member
  end

  resources :carousels, except: :destroy, concerns: :historical

  # Seat codes are section number plus row letter, e.g. /carousels/great-northern-carousel/5A
  scope "carousels/:carousel_id/:code", constraints: { code: /\d+[A-Za-z]/ }, controller: :seats do
    get "", action: :show, as: :carousel_seat
    patch "", action: :update
    get "edit", action: :edit, as: :edit_carousel_seat
    get "history", action: :history, as: :history_carousel_seat
  end
  resources :figures, except: :destroy, concerns: :historical
  resources :figure_types, path: "types", except: :destroy, concerns: :historical
  resources :makers, except: :destroy, concerns: :historical

  get "recent-changes", to: "versions#index", as: :recent_changes
  post "versions/:id/revert", to: "versions#revert", as: :revert_version

  resources :invitations, only: %i[ index create destroy ]
  resources :invitation_acceptances, path: "invitations/accept", param: :token, only: %i[ edit update ]
  resource :session
  resources :passwords, param: :token

  get "up" => "rails/health#show", as: :rails_health_check
end
