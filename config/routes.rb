Rails.application.routes.draw do
  resource :session, only: %i[new create destroy]
  resource :registration, only: %i[new create]
  resource :username_lookup, only: %i[new create]
  resource :password, only: %i[new create]
  get "passwords/:token/edit", to: "passwords#edit", as: :edit_password
  patch "passwords/:token", to: "passwords#update", as: :update_password

  resources :seat_slots, only: :index do
    post :hold, on: :member
    delete :release, on: :member
    get :checkout, on: :member
    post :pay, on: :member
  end

  namespace :admin do
    root "dashboard#index"
    resources :payments, only: [] do
      post :refund, on: :member
    end
    resource :concurrency_test, only: %i[show create]
  end

  get "test", to: "test_pages#show", as: :test_page
  root "seat_slots#index"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
