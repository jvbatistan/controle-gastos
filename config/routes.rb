Rails.application.routes.draw do
  root "totals#dashboard"

  resources :transactions, only: [:new, :create]

  resources :debts do
    get "/debts/new", to: redirect("/transactions/new")
    post :pay_all, on: :collection
  end
    
  resources :cards
  resources :totals, only: [:index]
  get 'dashboard', to: 'totals#dashboard'

  resources :classification_suggestions, only: [:index] do
    member do
      post :accept
      post :reject
      post :correct
    end
  end
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
