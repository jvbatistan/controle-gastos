Rails.application.routes.draw do
  root "totals#dashboard"

  devise_for :users

  resources :transactions, only: [:index, :new, :create, :edit, :update, :destroy]

  resources :cards
  resources :totals, only: [:index]
  get 'dashboard', to: 'totals#dashboard'

  resources :categories, except: [:show]
  resources :merchant_aliases, except: [:show]

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

  namespace :api do
    get "health",    to: "health#show"
    get "me",        to: "me#show"
    patch "me",      to: "me#update"
    post "register", to: "registrations#create"
    post "login",    to: "sessions#create"
    delete "logout", to: "sessions#destroy"

    resources :transactions, only: [:index, :create, :update, :destroy]
    resources :classification_suggestions, only: [:index] do
      member do
        post :accept
        post :reject
        post :correct
      end
    end
    resources :categories, only: [:index, :create, :update, :destroy]
    resources :cards, only: [:index, :create, :update, :destroy]

    get  "payments", to: "payments#index"
    post "payments/card_statements/:id/pay", to: "payments#pay_card_statement"
    post "payments/card_statements/:id/ignore", to: "payments#ignore_card_statement"
    post "payments/loose_expenses/:id/pay", to: "payments#pay_loose_expense"
    post "payments/loose_expenses/pay", to: "payments#pay_loose_expenses"
  end
end
