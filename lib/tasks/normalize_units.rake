namespace :data do
  desc 'Normalize units for Europe and EU27 aggregates'
  task normalize_units: :environment do
    mapping = {
      'population' => 'people',
      'gdp_per_capita_ppp' => 'international_dollars',
      'life_expectancy' => 'years',
      'birth_rate' => 'rate',
      'death_rate' => 'rate',
      'literacy_rate' => 'rate',
      'child_mortality_rate' => '%',
      'electricity_access' => '%',
      'health_expenditure_gdp_percent' => '% of GDP',
      'life_satisfaction' => 'score (0-10)'
    }

    scope = Metric.where(country: ['europe', 'european_union'])
    total = scope.count
    fixed = 0

    scope.find_each do |m|
      expected = mapping[m.metric_name] || m.unit
      next if m.unit == expected
      m.update_column(:unit, expected)
      fixed += 1
    end

    puts "Updated units for #{fixed} of #{total} aggregate records"
  end
end
