namespace :metrics do
  SEED_FILE = Rails.root.join("db/seeds/metrics.json")

  desc "Export all metrics to a JSON seed file for fast production loading"
  task export: :environment do
    puts "\n" + "=" * 70
    puts "📤 EXPORTING METRICS TO SEED FILE"
    puts "=" * 70

    metrics = Metric.all.order(:metric_name, :country, :year)
    count = metrics.count

    if count.zero?
      puts "❌ No metrics found in database. Run 'rails metrics:import' first."
      exit 1
    end

    # Export as array of hashes (excluding id, created_at, updated_at)
    data = metrics.map do |m|
      {
        country: m.country,
        metric_name: m.metric_name,
        metric_value: m.metric_value,
        year: m.year,
        unit: m.unit,
        source: m.source,
        description: m.description,
        coverage: m.coverage
      }
    end

    # Write to file with pretty formatting for git diffs
    File.write(SEED_FILE, JSON.pretty_generate(data))

    file_size = File.size(SEED_FILE)
    puts "\n✅ Exported #{count} metrics to #{SEED_FILE}"
    puts "   File size: #{(file_size / 1024.0).round(1)} KB"
    puts "\n💡 Commit this file to your repository for fast production deploys."
  end

  desc "Load metrics from seed file (fast, no API calls)"
  task load_seed: :environment do
    puts "\n" + "=" * 70
    puts "📥 LOADING METRICS FROM SEED FILE"
    puts "=" * 70

    # Check if table exists (might run before db:prepare completes)
    unless ActiveRecord::Base.connection.table_exists?(:metrics)
      puts "⏳ Metrics table not yet created, waiting for db:prepare..."
      puts "   (This is normal on first deploy)"
      exit 0
    end

    unless File.exist?(SEED_FILE)
      puts "❌ Seed file not found at #{SEED_FILE}"
      puts "   Run 'rails metrics:export' locally first, then commit the file."
      exit 1
    end

    start_time = Time.current
    data = JSON.parse(File.read(SEED_FILE))

    puts "   Found #{data.size} metrics in seed file"

    # Clear existing metrics and bulk insert
    Metric.transaction do
      Metric.delete_all
      puts "   Cleared existing metrics"

      # Insert in batches of 1000 for better performance
      batch_size = 1000
      inserted = 0

      data.each_slice(batch_size) do |batch|
        records = batch.map do |m|
          {
            country: m["country"],
            metric_name: m["metric_name"],
            metric_value: m["metric_value"],
            year: m["year"],
            unit: m["unit"],
            source: m["source"],
            description: m["description"],
            coverage: m["coverage"],
            created_at: Time.current,
            updated_at: Time.current
          }
        end

        Metric.insert_all(records)
        inserted += records.size
        print "\r   Inserted #{inserted}/#{data.size} metrics..."
      end
    end

    elapsed = (Time.current - start_time).round(2)
    puts "\n\n✅ Loaded #{data.size} metrics in #{elapsed}s"
  end

  desc "Refresh seed file: import fresh data then export"
  task refresh_seed: :environment do
    puts "\n🔄 Refreshing seed data..."
    puts "   Step 1: Import fresh data from APIs"
    Rake::Task["metrics:import"].invoke

    puts "\n   Step 2: Export to seed file"
    Rake::Task["metrics:export"].invoke

    puts "\n✅ Seed file refreshed! Don't forget to commit db/seeds/metrics.json"
  end
end
