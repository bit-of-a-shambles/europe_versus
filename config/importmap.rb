# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

# Chart.js for interactive charts
pin "chart.js", to: "https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"
pin "chart.js/auto", to: "https://cdn.jsdelivr.net/npm/chart.js@4.4.1/auto/+esm"

# html2canvas for chart image export
pin "html2canvas", to: "https://cdn.jsdelivr.net/npm/html2canvas@1.4.1/dist/html2canvas.esm.js"
