class Admin::PendingStatisticsController < ApplicationController
  before_action :set_pending_statistic, only: [:show, :approve, :reject]
  
  # Simple authentication for demo - replace with proper auth in production
  before_action :authenticate_admin
  
  def index
    @pending_statistics = PendingStatistic.includes(:id).order(created_at: :desc)
    @pending_count = PendingStatistic.pending.count
    @approved_count = PendingStatistic.approved.count
    @rejected_count = PendingStatistic.rejected.count
  end

  def show
  end

  def approve
    if @pending_statistic.approve!
      redirect_to admin_pending_statistics_path, notice: 'Statistic approved and published successfully!'
    else
      redirect_to admin_pending_statistic_path(@pending_statistic), alert: 'Failed to approve statistic.'
    end
  end

  def reject
    if @pending_statistic.reject!
      redirect_to admin_pending_statistics_path, notice: 'Statistic rejected.'
    else
      redirect_to admin_pending_statistic_path(@pending_statistic), alert: 'Failed to reject statistic.'
    end
  end
  
  private
  
  def set_pending_statistic
    @pending_statistic = PendingStatistic.find(params[:id])
  end
  
  # Simple authentication - replace with proper authentication system
  def authenticate_admin
    # For demo purposes, allow access if URL contains admin_key parameter
    # In production, use proper authentication like Devise
    unless params[:admin_key] == 'demo_admin_2025' || session[:admin_authenticated]
      if params[:admin_key] == 'demo_admin_2025'
        session[:admin_authenticated] = true
      else
        render plain: "Access denied. This is a demo admin interface. Add ?admin_key=demo_admin_2025 to the URL to access.", status: :unauthorized
        return
      end
    end
  end
end
