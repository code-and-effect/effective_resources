Rails.application.routes.draw do
  mount EffectiveResources::Engine => '/', as: 'effective_resources'
end

EffectiveResources::Engine.routes.draw do
  namespace :effective do
    resources :ajax, only: [] do
      get :users, on: :collection, as: :users
      get :organizations, on: :collection, as: :organizations
    end
  end
end
