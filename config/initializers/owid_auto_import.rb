# Auto-import OWID metrics on app startup
# This runs after database is ready and imports any new metrics from config/owid_metrics.yml

Rails.application.config.after_initialize do
  # Only run in production or when explicitly enabled
  # Skip in development/test to avoid slowing down startup
  auto_import = ENV["OWID_AUTO_IMPORT"].present? || Rails.env.production?

  next unless auto_import

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
  Thread.new do
    begin
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
          result = OwidMetricImporter.import_metric(metric_name, verbose: false)

          if result[:success]
            Rails.logger.info "✅ Imported #{metric_name}: #{result[:stored_count]} records"
          elsif result[:error]
            Rails.logger.warn "⚠️  Failed to import #{metric_name}: #{result[:error]}"
          end
        end

        Rails.logger.info "✅ OWID auto-import complete"
      else
        Rails.logger.info "✅ All OWID metrics already imported"
      end
    rescue => e
      Rails.logger.error "❌ OWID auto-import error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end
end
