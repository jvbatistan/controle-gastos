Rails.application.routes.draw do
  root "totals#dashboard"

  resources :transactions, only: [:index, :new, :create, :edit, :update, :destroy]

  resources :debts do
    get "/debts/new", to: redirect("/transactions/new")
    post :pay_all, on: :collection
  end

  get "/debts", to: redirect("/transactions")
    
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
  
  resources :card_statements, only: [] do
    member do
      post :add_payment
    end
  end
end
