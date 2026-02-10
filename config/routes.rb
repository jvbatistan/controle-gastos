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
    post "login",    to: "sessions#create"
    delete "logout", to: "sessions#destroy"

    resources :transactions, only: [:index]
    resources :categories, only: [:index]
  end
end
