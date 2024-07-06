Rails.application.routes.draw do
  root "totals#index"

  resources :debts
  resources :cards
  resources :totals, only: [:index]
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
