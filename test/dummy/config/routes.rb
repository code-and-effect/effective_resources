Rails.application.routes.draw do
  resources :things

  namespace :admin do
    resources :things do
      get :report, on: :collection

      post :approve, on: :member
      post :decline, on: :member
    end
  end

  scope module: 'effective' do
    resources :thangs
  end

  namespace :admin do
    resources :thangs do
      get :report, on: :collection

      post :approve, on: :member
      post :decline, on: :member
    end
  end

  resources :thongs, only: [:index, :show, :new, :destroy] do
    resources :build, controller: :thongs, only: [:show, :update]
  end

end
