Rails.application.routes.draw do
  root "totals#index"

  resources :debts do
    post :pay_all, on: :collection
  end
    
  resources :cards
  resources :totals, only: [:index]
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
