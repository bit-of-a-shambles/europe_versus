namespace :data do
  desc "Enrich descriptions for metrics (focus: Europe/EU aggregates and population records)"
  task enrich_aggregate_descriptions: :environment do
    aggregates = Metric.where(country: [ "europe", "european_union" ])

    updated = 0

    aggregates.find_each do |m|
      # Skip if a rich description already exists
      next if m.description.to_s.strip.size > 60

      country_label = case m.country
      when "europe" then "European"
      when "european_union" then "European Union (EU\u201127)"
      else m.country.humanize
      end

      new_desc = case m.metric_name
      when "gdp_per_capita_ppp"
                   "Population-weighted #{country_label} GDP per capita (PPP) using country populations as weights; adjusted for transcontinental populations."
      when "population"
                   "Total #{country_label} population (sum of country populations, adjusted for transcontinental populations)."
      when "child_mortality_rate"
                   "Population-weighted #{country_label} child mortality rate (deaths per 100 live births), using country populations as weights; adjusted for transcontinental populations."
      when "electricity_access"
                   "Population-weighted #{country_label} access to electricity (% of population), using country populations as weights; adjusted for transcontinental populations."
      when "health_expenditure_gdp_percent"
                   "Population-weighted #{country_label} health expenditure as a percentage of GDP, using country populations as weights; adjusted for transcontinental populations."
      when "life_satisfaction"
                   "Population-weighted #{country_label} life satisfaction score on the Cantril Ladder (0-10 scale), using country populations as weights; adjusted for transcontinental populations."
      else
                   nil
      end

      # Also replace very generic placeholders
      if new_desc && (m.description.blank? || m.description.start_with?("Calculated") || m.description =~ /Total population count/i)
        m.update_column(:description, new_desc)
        updated += 1
      end
    end

    puts "Enriched descriptions for #{updated} aggregate records"

    # Also upgrade generic population descriptions anywhere
    pop_updated = 0
    Metric.for_metric("population").where("LOWER(description) LIKE ?", "%total population count%").find_each do |m|
      m.update_column(:description, "Total annual population (headcount), sourced from Our World in Data.")
      pop_updated += 1
    end
    puts "Updated descriptions for #{pop_updated} population records"
  end
end
