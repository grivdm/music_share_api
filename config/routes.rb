Rails.application.routes.draw do
  get "up", to: "health#index"
  namespace :api do
    namespace :v1 do
      post "convert", to: "conversions#create"
    end
  end
end
