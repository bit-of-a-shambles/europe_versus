require "test_helper"

class EditionSubstackPublisherTest < ActiveSupport::TestCase
  FakeClient = Struct.new(:user_id) do
    def get_user_id = user_id
  end

  test "builds a reviewable draft with chart, reporting, and source" do
    publisher = EditionSubstackPublisher.new(
      edition: Edition.latest,
      base_url: "https://charts.example",
      client: FakeClient.new(42)
    )

    draft = publisher.build_post(FakeClient.new(42)).get_draft
    body = JSON.parse(draft.fetch(:draft_body))

    assert_equal Edition.latest.title, draft.fetch(:draft_title)
    assert_equal 42, draft.fetch(:draft_bylines).first.fetch("id")
    assert_includes body.to_json, "chart.png"
    assert_includes body.to_json, Edition.latest.chart.fetch("description")
    assert_includes body.to_json, "Source and method"
    assert_includes body.to_json, "subscribeWidget"
    assert_operator body.to_json.index("The American shorthand"), :<, body.to_json.index("chart.png")
  end
end
