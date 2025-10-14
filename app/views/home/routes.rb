Rails.application.routes.draw do
  root "home#index"

  # Methodology page
  get "/methodology", to: "home#methodology", as: :methodology

  # Statistics index page
  get "/statistics", to: "statistics#index", as: :statistics

  # Catch-all route for statistics - handles both underscore and hyphen formats
  # The controller will handle the conversion and redirection if needed
  get "/statistics/:id", to: "statistics#show", as: :statistic

  # Redirect contribute to GitHub since we use Our World in Data
  get "/contribute", to: redirect("https://github.com/Duartemartins/europe_versus"), as: :contribute

  # Favicon route
  get "/favicon.ico", to: redirect("/icon-192.png")

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by uptime monitors like UptimeRobot or New Relic to monitor application deployment.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
