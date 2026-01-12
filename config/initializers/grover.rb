# Grover configuration for server-side HTML to PNG rendering
# Used for generating Open Graph images for fact-check cards

Grover.configure do |config|
  config.options = {
    format: "png",
    viewport: {
      width: 1200,
      height: 630
    },
    # Wait for fonts to load
    wait_until: "networkidle0",
    # Launch options for Puppeteer
    launch_args: [ "--no-sandbox", "--disable-setuid-sandbox" ],
    # Use the system's Chrome/Chromium
    executable_path: ENV.fetch("GROVER_CHROME_PATH", nil)
  }

  # In development, allow local file access
  if Rails.env.development?
    config.options[:launch_args] << "--allow-file-access-from-files"
  end
end
