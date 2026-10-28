Rails.application.routes.draw do
  root "carousels#index"
  get "about", to: "pages#about", as: :about
  get "editor-guide", to: "pages#editor_guide", as: :editor_guide
  get "contribution-terms", to: "pages#contribution_terms", as: :contribution_terms
  resource :contribution_agreement, only: %i[ edit update ]

  concern :historical do
    get :history, on: :member
  end

  resources :carousels, except: :destroy, concerns: :historical do
    resources :video_analyses, path: "video-analyses", only: %i[ index new create show ] do
      member do
        post :apply
        post :retry
      end
    end
  end

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
  resources :editors, only: [] do
    resource :suspension, only: %i[ create destroy ], controller: "editor_suspensions"
    resource :video_analysis_access, only: %i[ create destroy ], controller: "video_analysis_accesses"
  end
  resources :invitation_acceptances, path: "invitations/accept", param: :token, only: %i[ edit update ]
  resource :session
  resources :passwords, param: :token

  get "up" => "rails/health#show", as: :rails_health_check
end
