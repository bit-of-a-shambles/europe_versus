class SitemapController < ApplicationController
  def show
    @editions = Edition.all
  end
end
