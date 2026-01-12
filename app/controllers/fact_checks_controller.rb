class FactChecksController < ApplicationController
  # Skip certain middleware for image endpoint
  skip_before_action :verify_authenticity_token, only: [ :image ]

  # GET /facts - List all published fact-check articles
  def index
    @fact_checks = FactCheck.all
  end

  # GET /facts/:slug - Show a single fact-check article
  def show
    @fact_check = FactCheck.find(params[:slug])
  rescue ActiveRecord::RecordNotFound
    flash[:alert] = "Article not found"
    redirect_to facts_path
  end

  # GET /facts/:slug.png - OG image for social sharing
  def image
    @fact_check = FactCheck.find(params[:slug])

    html = render_to_string(
      template: "fact_checks/image",
      layout: false,
      locals: { fact_check: @fact_check }
    )

    grover = Grover.new(html, format: "png", viewport: { width: 1200, height: 630 })
    png_data = grover.to_png

    send_data png_data,
              type: "image/png",
              disposition: "inline",
              filename: "#{@fact_check.slug}-fact-check.png"
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  # GET /embed/facts/:slug - Minimal embed for third-party sites
  def embed
    @fact_check = FactCheck.find(params[:slug])
    render layout: "embed"
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end
end
