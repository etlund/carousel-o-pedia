Rails.application.routes.draw do
  root "carousels#index"

  resources :carousels, only: %i[ index show ] do
    # Seat codes are section number plus row letter, e.g. /carousels/great-northern-carousel/5A
    get ":code", to: "seats#show", as: :seat, constraints: { code: /\d+[A-Za-z]/ }
  end
  resources :figures, only: %i[ index show ]
  resources :figure_types, path: "types", only: %i[ index show ]
  resources :makers, only: %i[ show ]

  get "up" => "rails/health#show", as: :rails_health_check
end
