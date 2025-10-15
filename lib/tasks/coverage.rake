namespace :coverage do
  desc "Open the SimpleCov coverage report in browser"
  task :show do
    coverage_file = Rails.root.join("coverage", "index.html")
    
    if File.exist?(coverage_file)
      system("open", coverage_file.to_s)
      puts "✅ Opening coverage report in browser..."
    else
      puts "❌ Coverage report not found!"
      puts "   Run 'bin/rails test' first to generate the report."
    end
  end
  
  desc "Clean coverage reports"
  task :clean do
    coverage_dir = Rails.root.join("coverage")
    
    if Dir.exist?(coverage_dir)
      FileUtils.rm_rf(coverage_dir)
      puts "✅ Coverage reports cleaned"
    else
      puts "ℹ️  No coverage directory to clean"
    end
  end
  
  desc "Run tests and open coverage report"
  task :report do
    puts "🧪 Running tests..."
    system("bin/rails test")
    puts "\n📊 Opening coverage report..."
    Rake::Task["coverage:show"].invoke
  end
end
