import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"
import html2canvas from "html2canvas"

// Connects to data-controller="chart"
export default class extends Controller {
  static targets = ["canvas", "container", "yearStart", "yearEnd", "countryCheckbox", "modeToggle", "exportBtn", "legend", "selectionCount"]
  static values = {
    data: Object,
    title: String,
    unit: String,
    metricName: String
  }

  // Color palette for chart lines - Swiss brutalist inspired
  static COLORS = {
    // Aggregates - bold distinct colors
    europe: { line: '#0066FF', bg: 'rgba(0, 102, 255, 0.1)' },           // Bright blue
    european_union: { line: '#003D99', bg: 'rgba(0, 61, 153, 0.1)' },    // Dark blue
    eurozone: { line: '#7C3AED', bg: 'rgba(124, 58, 237, 0.1)' },        // Purple
    non_euro_eu: { line: '#059669', bg: 'rgba(5, 150, 105, 0.1)' },      // Emerald green
    non_eu_europe: { line: '#0D9488', bg: 'rgba(13, 148, 136, 0.1)' },   // Teal
    // Global comparisons
    usa: { line: '#DC2626', bg: 'rgba(220, 38, 38, 0.1)' },              // Red
    china: { line: '#EA580C', bg: 'rgba(234, 88, 12, 0.1)' },            // Orange
    india: { line: '#16A34A', bg: 'rgba(22, 163, 74, 0.1)' },            // Green
    // Major EU - blues and teals
    germany: { line: '#0891B2', bg: 'rgba(8, 145, 178, 0.1)' },
    france: { line: '#6366F1', bg: 'rgba(99, 102, 241, 0.1)' },
    italy: { line: '#8B5CF6', bg: 'rgba(139, 92, 246, 0.1)' },
    spain: { line: '#D946EF', bg: 'rgba(217, 70, 239, 0.1)' },
    netherlands: { line: '#F97316', bg: 'rgba(249, 115, 22, 0.1)' },
    poland: { line: '#EAB308', bg: 'rgba(234, 179, 8, 0.1)' },
    sweden: { line: '#84CC16', bg: 'rgba(132, 204, 22, 0.1)' },
    denmark: { line: '#22C55E', bg: 'rgba(34, 197, 94, 0.1)' },
    // Non-EU European
    united_kingdom: { line: '#14B8A6', bg: 'rgba(20, 184, 166, 0.1)' },
    switzerland: { line: '#F43F5E', bg: 'rgba(244, 63, 94, 0.1)' },
    norway: { line: '#3B82F6', bg: 'rgba(59, 130, 246, 0.1)' },
    // Default fallback
    default: { line: '#6B7280', bg: 'rgba(107, 114, 128, 0.1)' }
  }

  connect() {
    this.chart = null
    this.mode = 'absolute' // 'absolute' or 'relative'
    this.selectedCountries = new Set(['europe', 'usa', 'china', 'india'])
    this.yearRange = { start: null, end: null }
    
    // Initialize once data is available
    if (this.hasDataValue && Object.keys(this.dataValue).length > 0) {
      this.initializeChart()
    }
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
    }
  }

  initializeChart() {
    // Set year range from data
    const years = this.dataValue.years || []
    if (years.length > 0) {
      this.yearRange.start = Math.min(...years)
      this.yearRange.end = Math.max(...years)
      
      // Update year selector displays
      if (this.hasYearStartTarget) this.yearStartTarget.value = this.yearRange.start
      if (this.hasYearEndTarget) this.yearEndTarget.value = this.yearRange.end
    }

    // Initialize country checkboxes based on available data
    this.initializeCountryFilters()
    
    // Render the chart
    this.renderChart()
  }

  initializeCountryFilters() {
    if (!this.hasCountryCheckboxTarget) return
    
    const availableCountries = Object.keys(this.dataValue.countries || {})
    
    this.countryCheckboxTargets.forEach(checkbox => {
      const country = checkbox.dataset.country
      // Disable checkbox if country has no data
      if (!availableCountries.includes(country)) {
        checkbox.disabled = true
        checkbox.closest('label')?.classList.add('opacity-40', 'cursor-not-allowed')
      }
      // Set initial checked state
      checkbox.checked = this.selectedCountries.has(country)
    })
    
    // Update selection count display
    this.updateSelectionCount()
  }

  renderChart() {
    if (!this.hasCanvasTarget) return

    // Destroy existing chart
    if (this.chart) {
      this.chart.destroy()
    }

    const datasets = this.buildDatasets()
    const years = this.getFilteredYears()

    // Use globally loaded Chart.js
    if (typeof Chart === 'undefined') {
      console.error('Chart.js not loaded')
      return
    }

    const ctx = this.canvasTarget.getContext('2d')
    
    this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: years,
        datasets: datasets
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          mode: 'index',
          intersect: false
        },
        plugins: {
          legend: {
            display: false // We'll use custom legend
          },
          tooltip: {
            backgroundColor: '#000',
            titleColor: '#fff',
            bodyColor: '#fff',
            borderColor: '#000',
            borderWidth: 2,
            padding: 12,
            titleFont: {
              family: 'ui-monospace, monospace',
              size: 12,
              weight: 'bold'
            },
            bodyFont: {
              family: 'ui-monospace, monospace',
              size: 11
            },
            itemSort: (a, b) => {
              // Sort tooltip items by value descending (highest first)
              const aVal = a.parsed.y ?? -Infinity
              const bVal = b.parsed.y ?? -Infinity
              return bVal - aVal
            },
            callbacks: {
              label: (context) => {
                const value = context.parsed.y
                if (value === null || value === undefined) return null
                
                const formattedValue = this.formatValue(value)
                return `${context.dataset.label}: ${formattedValue}`
              }
            }
          }
        },
        scales: {
          x: {
            grid: {
              color: 'rgba(0, 0, 0, 0.1)',
              drawBorder: true,
              borderColor: '#000',
              borderWidth: 2
            },
            ticks: {
              font: {
                family: 'ui-monospace, monospace',
                size: 11
              },
              color: '#000'
            }
          },
          y: {
            grid: {
              color: 'rgba(0, 0, 0, 0.1)',
              drawBorder: true,
              borderColor: '#000',
              borderWidth: 2
            },
            ticks: {
              font: {
                family: 'ui-monospace, monospace',
                size: 11
              },
              color: '#000',
              callback: (value) => this.formatValue(value)
            },
            title: {
              display: true,
              text: this.mode === 'relative' ? 'Change from baseline (%)' : (this.unitValue || ''),
              font: {
                family: 'ui-monospace, monospace',
                size: 11,
                weight: 'bold'
              },
              color: '#000'
            }
          }
        }
      }
    })

    // Update custom legend
    this.updateLegend(datasets)
  }

  buildDatasets() {
    const countries = this.dataValue.countries || {}
    const years = this.getFilteredYears()
    const datasets = []
    
    // Threshold below which coverage is considered "incomplete" (70% of European population)
    const INCOMPLETE_THRESHOLD = 0.7

    // Sort countries: aggregates first, then global, then alphabetically
    const sortedCountries = Array.from(this.selectedCountries).sort((a, b) => {
      const order = { europe: 0, european_union: 1, usa: 2, china: 3, india: 4 }
      const aOrder = order[a] ?? 99
      const bOrder = order[b] ?? 99
      if (aOrder !== bOrder) return aOrder - bOrder
      return a.localeCompare(b)
    })

    sortedCountries.forEach(countryKey => {
      const countryData = countries[countryKey]
      if (!countryData || !countryData.data) return

      const color = this.constructor.COLORS[countryKey] || this.constructor.COLORS.default
      const isAggregate = countryData.is_aggregate || false
      const coverageData = countryData.coverage || {}
      
      // Check if this aggregate has any incomplete years in the current range
      let hasIncompleteYears = false
      if (isAggregate && Object.keys(coverageData).length > 0) {
        hasIncompleteYears = years.some(year => {
          const coverage = coverageData[year]
          return coverage !== undefined && coverage !== null && coverage < INCOMPLETE_THRESHOLD
        })
      }
      
      const data = years.map(year => {
        const value = countryData.data[year]
        if (value === null || value === undefined) return null
        
        if (this.mode === 'relative') {
          return this.calculateRelativeChange(countryData.data, year, years[0])
        }
        return parseFloat(value)
      })
      
      // Build segment configuration for dotted/solid line segments based on coverage
      let segment = undefined
      if (isAggregate && Object.keys(coverageData).length > 0) {
        segment = {
          borderDash: ctx => {
            // Get the year for this segment (convert to string for object key lookup)
            const index = ctx.p0DataIndex
            const year = String(years[index])
            const coverage = coverageData[year]
            // Use dotted line if coverage is below threshold (70% population)
            if (coverage !== undefined && coverage !== null && coverage < INCOMPLETE_THRESHOLD) {
              return [5, 5] // Dotted line pattern
            }
            return undefined // Solid line
          }
        }
      }

      datasets.push({
        label: countryData.name || this.formatCountryName(countryKey),
        data: data,
        borderColor: color.line,
        backgroundColor: color.bg,
        borderWidth: countryKey === 'europe' || countryKey === 'european_union' ? 3 : 2,
        pointRadius: 0,
        pointHoverRadius: 6,
        tension: 0.1,
        fill: false,
        spanGaps: true,
        segment: segment,
        // Store metadata for tooltip
        countryKey: countryKey,
        coverageData: coverageData,
        isAggregate: isAggregate
      })
    })

    return datasets
  }

  calculateRelativeChange(data, currentYear, baseYear) {
    const baseValue = data[baseYear]
    const currentValue = data[currentYear]
    
    if (!baseValue || !currentValue || baseValue === 0) return null
    
    return ((currentValue - baseValue) / baseValue) * 100
  }

  getFilteredYears() {
    const allYears = (this.dataValue.years || []).sort((a, b) => a - b)
    return allYears.filter(year => 
      year >= this.yearRange.start && year <= this.yearRange.end
    )
  }

  formatValue(value) {
    if (value === null || value === undefined) return '—'
    
    const num = parseFloat(value)
    if (isNaN(num)) return '—'
    
    if (this.mode === 'relative') {
      return `${num >= 0 ? '+' : ''}${num.toFixed(1)}%`
    }
    
    // Format based on magnitude
    if (Math.abs(num) >= 1000000000) {
      return `${(num / 1000000000).toFixed(1)}B`
    } else if (Math.abs(num) >= 1000000) {
      return `${(num / 1000000).toFixed(1)}M`
    } else if (Math.abs(num) >= 1000) {
      return `${(num / 1000).toFixed(1)}K`
    } else if (Number.isInteger(num)) {
      return num.toLocaleString()
    } else {
      return num.toFixed(2)
    }
  }

  formatCountryName(key) {
    return key.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())
  }

  updateLegend(datasets) {
    if (!this.hasLegendTarget) return
    
    const legendHtml = datasets.map(ds => `
      <div class="flex items-center gap-2 px-3 py-1.5 border-2 border-black text-xs font-mono">
        <span class="w-3 h-3 rounded-full" style="background-color: ${ds.borderColor}"></span>
        <span>${ds.label}</span>
      </div>
    `).join('')
    
    this.legendTarget.innerHTML = legendHtml
  }

  // Event handlers
  toggleMode(event) {
    const newMode = event.target.dataset.mode
    if (newMode === this.mode) return
    
    this.mode = newMode
    
    // Update toggle button styles
    this.modeToggleTargets.forEach(btn => {
      const isActive = btn.dataset.mode === this.mode
      btn.classList.toggle('bg-black', isActive)
      btn.classList.toggle('text-white', isActive)
      btn.classList.toggle('bg-white', !isActive)
      btn.classList.toggle('text-black', !isActive)
    })
    
    this.renderChart()
  }

  updateYearRange(event) {
    const target = event.target
    const value = parseInt(target.value)
    
    if (target.dataset.chartTarget === 'yearStart') {
      this.yearRange.start = value
    } else if (target.dataset.chartTarget === 'yearEnd') {
      this.yearRange.end = value
    }
    
    // Ensure start <= end
    if (this.yearRange.start > this.yearRange.end) {
      if (target.dataset.chartTarget === 'yearStart') {
        this.yearRange.end = this.yearRange.start
        if (this.hasYearEndTarget) this.yearEndTarget.value = this.yearRange.end
      } else {
        this.yearRange.start = this.yearRange.end
        if (this.hasYearStartTarget) this.yearStartTarget.value = this.yearRange.start
      }
    }
    
    this.renderChart()
  }

  toggleCountry(event) {
    const checkbox = event.target
    const country = checkbox.dataset.country
    
    if (checkbox.checked) {
      this.selectedCountries.add(country)
    } else {
      this.selectedCountries.delete(country)
    }
    
    this.updateSelectionCount()
    this.renderChart()
  }

  selectRegionGroup(event) {
    const group = event.target.dataset.group
    
    // Define region groups using official EU classifications
    const groups = {
      'aggregates': ['europe', 'european_union'],
      'global': ['usa', 'china', 'india'],
      // EU-27: All current EU member states
      'eu-27': [
        'germany', 'france', 'italy', 'spain', 'netherlands', 'poland', 'sweden',
        'denmark', 'finland', 'austria', 'belgium', 'ireland', 'portugal', 'greece',
        'czechia', 'czech_republic', 'hungary', 'romania', 'croatia', 'bulgaria', 'slovakia',
        'slovenia', 'estonia', 'latvia', 'lithuania', 'luxembourg', 'malta', 'cyprus'
      ],
      // Eurozone: The 20 countries using the Euro
      'eurozone': [
        'germany', 'france', 'italy', 'spain', 'netherlands', 'belgium', 'austria',
        'ireland', 'portugal', 'greece', 'finland', 'slovakia', 'slovenia', 'estonia',
        'latvia', 'lithuania', 'luxembourg', 'malta', 'cyprus', 'croatia'
      ],
      // Non-Euro EU: EU members not using the Euro
      'non-euro-eu': ['poland', 'sweden', 'denmark', 'czechia', 'czech_republic', 'hungary', 'romania', 'bulgaria'],
      // Non-EU European countries (UK, Switzerland, Norway, Iceland, etc.)
      'non-eu': ['united_kingdom', 'switzerland', 'norway', 'iceland'],
      'all': Object.keys(this.dataValue.countries || {}),
      'clear': []
    }

    const countriesToSelect = groups[group] || []
    
    if (group === 'clear') {
      this.selectedCountries.clear()
    } else if (group === 'all') {
      this.selectedCountries = new Set(countriesToSelect)
    } else {
      // Toggle: if all are selected, deselect; otherwise select all
      const allSelected = countriesToSelect.every(c => this.selectedCountries.has(c))
      countriesToSelect.forEach(c => {
        if (allSelected) {
          this.selectedCountries.delete(c)
        } else {
          this.selectedCountries.add(c)
        }
      })
    }

    // Update checkboxes
    this.countryCheckboxTargets.forEach(checkbox => {
      checkbox.checked = this.selectedCountries.has(checkbox.dataset.country)
    })

    this.updateSelectionCount()
    this.renderChart()
  }

  updateSelectionCount() {
    if (!this.hasSelectionCountTarget) return
    
    const count = this.selectedCountries.size
    this.selectionCountTarget.textContent = `${count} selected`
  }

  async exportImage() {
    if (!this.hasContainerTarget) return
    
    const container = this.containerTarget
    
    try {
      // Show loading state
      const btn = this.exportBtnTarget
      const originalText = btn.textContent
      btn.textContent = 'Exporting...'
      btn.disabled = true
      
      // Create canvas from the chart container
      const canvas = await html2canvas(container, {
        backgroundColor: '#ffffff',
        scale: 2, // Higher resolution
        logging: false,
        useCORS: true
      })

      // Create download link
      const link = document.createElement('a')
      const metricName = this.metricNameValue || 'chart'
      link.download = `${metricName}-europeversus-${new Date().toISOString().split('T')[0]}.png`
      link.href = canvas.toDataURL('image/png')
      link.click()

      // Reset button
      btn.textContent = originalText
      btn.disabled = false
    } catch (error) {
      console.error('Export failed:', error)
      alert('Failed to export image. Please try again.')
    }
  }

  async copyToClipboard() {
    if (!this.hasContainerTarget) return
    
    try {
      const canvas = await html2canvas(this.containerTarget, {
        backgroundColor: '#ffffff',
        scale: 2,
        logging: false
      })

      canvas.toBlob(async (blob) => {
        try {
          await navigator.clipboard.write([
            new ClipboardItem({ 'image/png': blob })
          ])
          // Show brief success feedback
          const btn = event.target
          const originalText = btn.textContent
          btn.textContent = 'Copied!'
          setTimeout(() => { btn.textContent = originalText }, 1500)
        } catch (err) {
          console.error('Clipboard write failed:', err)
          alert('Failed to copy to clipboard. Your browser may not support this feature.')
        }
      }, 'image/png')
    } catch (error) {
      console.error('Copy failed:', error)
    }
  }
}
