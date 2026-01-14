# Load metrics from seed file on startup (for ephemeral SQLite environments like Koyeb)
# This file is named with 00_ prefix to run early in initialization

Rails.application.config.after_initialize do
  # Only run in production
  next unless Rails.env.production?

  # Skip during asset precompilation or rake tasks
  next if defined?(Rake) || ENV["SKIP_SEED_LOAD"].present?

  seed_file = Rails.root.join("db/seeds/metrics.json")

  # Check if seed file exists
  unless File.exist?(seed_file)
    Rails.logger.info "Seed file not found at #{seed_file}, skipping seed load"
    next
  end

  begin
    ActiveRecord::Base.connection.verify!

    # Run migrations if needed (creates tables)
    unless ActiveRecord::Base.connection.table_exists?(:metrics)
      Rails.logger.info "📦 Running database migrations..."
      ActiveRecord::MigrationContext.new(Rails.root.join("db/migrate")).migrate
    end

    # Check if we need to load seed data
    if Metric.count.zero?
      Rails.logger.info "📥 Loading metrics from seed file..."

      start_time = Time.current
      data = JSON.parse(File.read(seed_file))

      # Bulk insert in batches
      batch_size = 1000
      inserted = 0

      Metric.transaction do
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
        end
      end

      elapsed = (Time.current - start_time).round(2)
      Rails.logger.info "✅ Loaded #{inserted} metrics in #{elapsed}s"
    else
      Rails.logger.info "Seed file cleaned up - data is now loaded dynamically from external sources"
    end
  rescue => e
    Rails.logger.error "Failed to load seed data: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
  end
end
