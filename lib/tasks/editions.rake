namespace :editions do
  desc "Create a Substack draft for an edition (never publishes it)"
  task :substack_draft, [ :slug ] => :environment do |_task, args|
    abort "Usage: bin/rails 'editions:substack_draft[edition-slug]'" if args[:slug].blank?

    base_url = ENV.fetch("PUBLIC_BASE_URL") do
      abort "Set PUBLIC_BASE_URL to the deployed site URL so Substack can fetch the chart image."
    end

    edition = Edition.find(args[:slug])
    response = EditionSubstackPublisher.new(edition: edition, base_url: base_url).create_draft
    puts "Created Substack draft for Edition № #{edition.issue_number}: #{response.inspect}"
    if edition.substack["preview_text"].present?
      puts "Preview text to paste into Substack: #{edition.substack.fetch('preview_text')}"
    end
  end
end
