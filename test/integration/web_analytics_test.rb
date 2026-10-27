require "test_helper"

class WebAnalyticsTest < ActionDispatch::IntegrationTest
  setup do
    @original_token = Rails.configuration.x.cloudflare_web_analytics_token
  end

  teardown do
    Rails.configuration.x.cloudflare_web_analytics_token = @original_token
  end

  test "tracking is disabled outside production even with a site token in the environment" do
    original_env_token = ENV["CLOUDFLARE_WEB_ANALYTICS_TOKEN"]
    ENV["CLOUDFLARE_WEB_ANALYTICS_TOKEN"] = "test-site-token"

    get root_path

    assert_response :success
    assert_select "script[src*='cloudflareinsights.com']", count: 0
  ensure
    ENV["CLOUDFLARE_WEB_ANALYTICS_TOKEN"] = original_env_token
  end

  test "configured tracking loads once in the head with SPA support and no Turbo reevaluation" do
    Rails.configuration.x.cloudflare_web_analytics_token = "test-site-token"

    [ root_path, carousels_path, contribution_terms_path ].each do |path|
      get path

      assert_response :success
      assert_select "script[src*='cloudflareinsights.com']", count: 1
      assert_select "head script[src='https://static.cloudflareinsights.com/beacon.min.js'][defer][data-turbo-eval='false']", count: 1 do |scripts|
        assert_equal({ "token" => "test-site-token", "spa" => true }, JSON.parse(scripts.first["data-cf-beacon"]))
      end
    end
  end

  test "missing and blank tokens omit the beacon" do
    [ nil, "", " " ].each do |token|
      Rails.configuration.x.cloudflare_web_analytics_token = token

      get root_path

      assert_response :success
      assert_select "script[src*='cloudflareinsights.com']", count: 0
    end
  end

  test "the privacy page discloses Cloudflare analytics" do
    get contribution_terms_path

    assert_select "p", /Cloudflare Web Analytics.*aggregate traffic/m
    assert_select "a[href='https://www.cloudflare.com/web-analytics/']"
  end
end
