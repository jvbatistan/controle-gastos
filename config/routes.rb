Rails.application.routes.draw do
  devise_for :users, skip: :all

  root to: "api/health#show"

  namespace :api do
    get "dashboard", to: "dashboard#show"
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
