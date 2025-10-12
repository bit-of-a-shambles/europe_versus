require "test_helper"

class Admin::PendingStatisticsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @pending_statistic = pending_statistics(:europe_population)
  end

  test "should get index" do
    get admin_pending_statistics_url, params: { admin_key: "demo_admin_2025" }
    assert_response :success
  end

  test "should get show" do
    get admin_pending_statistic_url(@pending_statistic), params: { admin_key: "demo_admin_2025" }
    assert_response :success
  end

  test "should approve pending statistic" do
    patch approve_admin_pending_statistic_url(@pending_statistic), params: { admin_key: "demo_admin_2025" }
    assert_response :redirect
  end

  test "should reject pending statistic" do
    patch reject_admin_pending_statistic_url(@pending_statistic), params: { admin_key: "demo_admin_2025" }
    assert_response :redirect
  end
end
