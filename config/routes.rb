Rails.application.routes.draw do
  mount EffectiveResources::Engine => '/', as: 'effective_resources'
end

EffectiveResources::Engine.routes.draw do

  namespace :admin do
    resources :select2_ajax, only: [] do
      get :users, on: :collection
      get :organizations, on: :collection
    end
  end

end
