# Auto-import OWID metrics on app startup
# This runs after database is ready and imports any new metrics from config/owid_metrics.yml

Rails.application.config.after_initialize do
  # Only run in production or when explicitly enabled
  # Skip in development/test to avoid slowing down startup
  auto_import = ENV["OWID_AUTO_IMPORT"].present? || Rails.env.production?

  next unless auto_import

  # Skip during migrations or when SKIP_OWID_AUTO_IMPORT is set
  # This prevents database locks during data initialization
  next if ENV["SKIP_OWID_AUTO_IMPORT"].present?

  # Wait for database to be ready
  begin
    ActiveRecord::Base.connection.verify!
    # Check if metrics table exists
    unless ActiveRecord::Base.connection.table_exists?(:metrics)
      Rails.logger.info "Metrics table not yet created, skipping OWID auto-import"
      next
    end
  rescue => e
    Rails.logger.info "Database not ready (#{e.message}), skipping OWID auto-import"
    next
  end

  # Import metrics in background to not block startup
  # Add delay to ensure other initialization is complete
  Thread.new do
    begin
      # Wait longer to ensure migrations/seeds are done and web server is ready
      sleep 10

      # Acquire an advisory lock via file to prevent concurrent imports
      lock_file = Rails.root.join("tmp", "owid_import.lock")
      File.open(lock_file, File::RDWR | File::CREAT) do |f|
        unless f.flock(File::LOCK_EX | File::LOCK_NB)
          Rails.logger.info "OWID import already running in another process, skipping"
          next
        end

        Rails.logger.info "🌍 Checking for new OWID metrics..."

        # Get all configured metrics
        configured_metrics = OwidMetricImporter.yaml_configs.keys

        # Check which ones need importing (no data yet)
        new_metrics = configured_metrics.select do |metric_name|
          Metric.where(metric_name: metric_name).empty?
        end

        if new_metrics.any?
          Rails.logger.info "📥 Auto-importing #{new_metrics.size} new metric(s): #{new_metrics.join(', ')}"

          new_metrics.each do |metric_name|
            begin
              result = OwidMetricImporter.import_metric(metric_name, verbose: false)

              if result[:success]
                Rails.logger.info "✅ Imported #{metric_name}: #{result[:stored_count]} records"
              elsif result[:error]
                Rails.logger.warn "⚠️  Failed to import #{metric_name}: #{result[:error]}"
              end
            rescue => e
              Rails.logger.error "❌ Error importing #{metric_name}: #{e.message}"
              # Continue with other metrics even if one fails
            end

            # Add a small delay between metrics to reduce database contention
            sleep 1
          end

          Rails.logger.info "✅ OWID auto-import complete"
        else
          Rails.logger.info "✅ All OWID metrics already imported"
        end
      end
    rescue => e
      Rails.logger.error "❌ OWID auto-import error: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
    end
  end
end
