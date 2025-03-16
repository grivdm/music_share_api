Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      post "convert", to: "conversions#create"
    end
  end
end
