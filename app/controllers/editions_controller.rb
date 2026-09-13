require "csv"

class EditionsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :chart_image

  def index
    @editions = Edition.all
  end

  def show
    @edition = Edition.find(params[:slug])
    @chart = EditorialChartPresenter.new(@edition)
  rescue ActiveRecord::RecordNotFound
    redirect_to editions_path, alert: "Edition not found"
  end

  def chart_image
    @edition = Edition.find(params[:slug])
    @chart = EditorialChartPresenter.new(@edition)

    html = render_to_string(
      template: "editions/chart_image",
      layout: false,
      formats: [ :html ]
    )
    png = Grover.new(
      html,
      format: "png",
      viewport: { width: 1200, height: @chart.image_height }
    ).to_png

    send_data png,
      type: "image/png",
      disposition: "inline",
      filename: "#{@edition.slug}-chart.png"
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def data
    edition = Edition.find(params[:slug])
    chart = EditorialChartPresenter.new(edition)
    csv = CSV.generate do |rows|
      rows << chart.csv_headers
      chart.csv_rows.each { |row| rows << row }
    end

    send_data csv,
      type: "text/csv; charset=utf-8",
      disposition: "attachment",
      filename: "#{edition.slug}-data.csv"
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end
end
