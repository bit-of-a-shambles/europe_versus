Rails.application.routes.draw do
  namespace :admin do
    resources :pending_statistics, only: [:index, :show] do
      member do
        patch :approve
        patch :reject
      end
    end
  end
  root "home#index"
  
  # Methodology page
  get "/methodology", to: "home#methodology", as: :methodology
  
  # Specific data pages - using Our World in Data chart names (must come before resources :statistics)
  get "/statistics/gdp-per-capita-ppp", to: "statistics#chart", as: :gdp_statistics
  get "/statistics/population", to: "statistics#chart", as: :population_statistics_detail
  get "/statistics/child-mortality-rate", to: "statistics#chart", as: :child_mortality_statistics
  get "/statistics/electricity-access", to: "statistics#chart", as: :electricity_access_statistics
  
  # Redirect old metric name format (with underscores) to new format (with dashes)
  get "/statistics/gdp_per_capita_ppp", to: redirect("/statistics/gdp-per-capita-ppp")
  get "/statistics/child_mortality_rate", to: redirect("/statistics/child-mortality-rate")
  get "/statistics/electricity_access", to: redirect("/statistics/electricity-access")
  
  resources :statistics, only: [:index, :show]
  
  # Legacy URLs redirect to new /statistics/ paths
  get "/gdp-per-capita-worldbank", to: redirect("/statistics/gdp-per-capita-ppp")
  get "/population", to: redirect("/statistics/population")
  get "/child-mortality-rate", to: redirect("/statistics/child-mortality-rate")
  get "/electricity-access", to: redirect("/statistics/electricity-access")
  
  # Short aliases
  get "/gdp", to: redirect("/statistics/gdp-per-capita-ppp")
  get "/child-mortality", to: redirect("/statistics/child-mortality-rate")
  
  # Redirect contribute to GitHub since we use Our World in Data
  get "/contribute", to: redirect("https://github.com/duartemartins/europeversus"), as: :contribute
  
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
