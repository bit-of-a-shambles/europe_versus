namespace :owid do
  desc "Bulk import metrics from a simple list of OWID slugs"
  task :bulk_import, [ :slugs_file ] => :environment do |t, args|
    slugs_file = args[:slugs_file] || "config/owid_slugs.txt"

    unless File.exist?(slugs_file)
      puts "❌ File not found: #{slugs_file}"
      puts ""
      puts "Create a file with one OWID slug per line:"
      puts "  renewable-energy-consumption"
      puts "  co2-emissions-per-capita"
      puts "  life-expectancy"
      puts ""
      puts "Optionally add custom name and year range:"
      puts "  renewable-energy-consumption|renewable_energy|2000|2024"
      puts ""
      exit 1
    end

    puts "\n📥 Bulk importing OWID metrics..."
    puts "=" * 60

    lines = File.readlines(slugs_file).map(&:strip).reject(&:empty?).reject { |l| l.start_with?("#") }

    lines.each_with_index do |line, index|
      # Parse line format: slug|name|start_year|end_year
      parts = line.split("|").map(&:strip)
      slug = parts[0]
      name = parts[1] || slug.gsub("-", "_")
      start_year = (parts[2] || 1990).to_i
      end_year = (parts[3] || 2024).to_i

      puts "\n[#{index + 1}/#{lines.size}] Importing #{name} (#{slug})..."

      # Fetch metadata first to get description and unit
      metadata_result = OurWorldInDataService.fetch_chart_data(slug, start_year: end_year, end_year: end_year)

      if metadata_result[:error]
        puts "   ⚠️  Skipping - could not fetch metadata: #{metadata_result[:error]}"
        next
      end

      unit = metadata_result.dig(:metadata, :unit).presence || "units"
      description = metadata_result.dig(:metadata, :description).presence || "Data from OWID: #{slug}"

      # Add to importer config dynamically
      config = {
        owid_slug: slug,
        start_year: start_year,
        end_year: end_year,
        unit: unit,
        description: description.truncate(200),
        aggregation_method: :population_weighted
      }

      # Add to runtime configs
      OwidMetricImporter.add_metric_config(name, **config)

      # Import the metric
      result = OwidMetricImporter.import_metric(name, verbose: true)

      if result[:success]
        puts "   ✅ Success - #{result[:stored_count]} records imported"
        puts ""
        puts "   Add to app/services/owid_metric_importer.rb:"
        puts "   '#{name}' => {"
        puts "     owid_slug: '#{slug}',"
        puts "     start_year: #{start_year},"
        puts "     end_year: #{end_year},"
        puts "     unit: '#{unit}',"
        puts "     description: '#{description.truncate(100)}',"
        puts "     aggregation_method: :population_weighted"
        puts "   },"
      else
        puts "   ❌ Failed: #{result[:error]}"
      end
    end

    puts "\n" + "=" * 60
    puts "✅ Bulk import complete!"
    puts ""
    puts "💡 Next steps:"
    puts "   1. Review the generated configs above"
    puts "   2. Add them to app/services/owid_metric_importer.rb"
    puts "   3. Re-run bin/rails 'owid:import[metric_name]' if needed"
  end

  desc "Generate owid_slugs.txt template file"
  task create_slugs_template: :environment do
    template_file = "config/owid_slugs.txt"

    if File.exist?(template_file)
      puts "❌ File already exists: #{template_file}"
      puts "   Delete it first or use a different filename"
      exit 1
    end

    template = <<~TEMPLATE
      # OWID Bulk Import Configuration
      # One slug per line. Optionally specify: slug|metric_name|start_year|end_year
      #
      # Format examples:
      #   renewable-energy-consumption
      #   co2-emissions-per-capita|co2_emissions|2000|2024
      #   life-expectancy|life_expectancy|1960|2024
      #
      # Lines starting with # are ignored

      # Example metrics (uncomment to import):
      # renewable-energy-consumption
      # co2-emissions-per-capita
      # life-expectancy
      # gdp-per-capita
      # human-development-index
    TEMPLATE

    File.write(template_file, template)
    puts "✅ Created template: #{template_file}"
    puts ""
    puts "Edit the file and add OWID slugs, then run:"
    puts "  bin/rails owid:bulk_import"
  end

  desc "Quick import: just provide slug(s) directly"
  task :quick, [ :slugs ] => :environment do |t, args|
    unless args[:slugs]
      puts "Usage: bin/rails 'owid:quick[slug1,slug2,slug3]'"
      puts ""
      puts "Example:"
      puts "  bin/rails 'owid:quick[renewable-energy-consumption,co2-emissions-per-capita]'"
      exit 1
    end

    slugs = args[:slugs].split(",").map(&:strip)

    puts "\n⚡ Quick importing #{slugs.size} metric(s)..."
    puts "=" * 60

    slugs.each_with_index do |slug, index|
      name = slug.gsub("-", "_")

      puts "\n[#{index + 1}/#{slugs.size}] #{name} (#{slug})..."

      # Fetch a small sample to get metadata
      metadata_result = OurWorldInDataService.fetch_chart_data(slug, start_year: 2024, end_year: 2024)

      if metadata_result[:error]
        puts "   ❌ Failed: #{metadata_result[:error]}"
        next
      end

      unit = metadata_result.dig(:metadata, :unit).presence || "units"
      description = metadata_result.dig(:metadata, :description).presence || "Data from OWID: #{slug}"

      # Create config and add to runtime
      config = {
        owid_slug: slug,
        start_year: 1990,
        end_year: 2024,
        unit: unit,
        description: description.truncate(200),
        aggregation_method: :population_weighted
      }

      OwidMetricImporter.add_metric_config(name, **config)

      # Import the metric
      result = OwidMetricImporter.import_metric(name, verbose: true)

      if result[:success]
        puts "   ✅ Imported #{result[:stored_count]} records"

        # Show the config to add
        puts ""
        puts "   📋 Add this to METRIC_CONFIGS:"
        puts "   '#{name}' => {"
        puts "     owid_slug: '#{slug}',"
        puts "     start_year: 1990,"
        puts "     end_year: 2024,"
        puts "     unit: '#{unit}',"
        puts "     description: '#{description.truncate(100)}',"
        puts "     aggregation_method: :population_weighted"
        puts "   },"
      else
        puts "   ❌ Failed: #{result[:error]}"
      end
    end

    puts "\n" + "=" * 60
    puts "✅ Quick import complete!"
  end
end
