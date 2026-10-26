require "test_helper"
require "yaml"

class ApplicationIdentityTest < ActiveSupport::TestCase
  test "renamed application preserves the existing session cookie key" do
    assert_equal "CarouselOPedia::Application", Rails.application.class.name
    assert_equal "_carousel_pedia_session", Rails.application.config.session_options[:key]
  end

  test "renamed deployment continues using the existing persistent storage volume" do
    deployment = YAML.load_file(Rails.root.join("config/deploy.yml"))
    assert_equal "carousel_o_pedia", deployment.fetch("service")
    assert_equal "carousel_o_pedia", deployment.fetch("image")
    assert_includes deployment.fetch("volumes"), "carousel_pedia_storage:/rails/storage"
  end
end
