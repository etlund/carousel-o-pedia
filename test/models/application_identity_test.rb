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
    assert_equal "etlund/carousel-o-pedia", deployment.fetch("image")
    assert_includes deployment.fetch("volumes"), "carousel_pedia_storage:/rails/storage"
  end

  test "deployment uses the production domain and authenticated registry" do
    deployment = YAML.load_file(Rails.root.join("config/deploy.yml"))

    assert_equal [ "201.79.38.100" ], deployment.fetch("servers").fetch("web")
    assert_equal true, deployment.fetch("proxy").fetch("ssl")
    assert_equal "carouselopedia.org", deployment.fetch("proxy").fetch("host")
    assert_equal "ghcr.io", deployment.fetch("registry").fetch("server")
    assert_equal "etlund", deployment.fetch("registry").fetch("username")
    assert_equal [ "KAMAL_REGISTRY_PASSWORD" ], deployment.fetch("registry").fetch("password")
    assert_equal "amd64", deployment.fetch("builder").fetch("arch")
    assert_equal "root", deployment.fetch("ssh").fetch("user")
    assert_includes deployment.fetch("env").fetch("secret"), "SECRET_KEY_BASE"
  end

  test "production schedules private off-server database backups" do
    deployment = YAML.load_file(Rails.root.join("config/deploy.yml"))
    environment = deployment.fetch("env")
    assert_equal "carouselopedia-backups", environment.fetch("clear").fetch("BACKUP_BUCKET")
    assert_equal "https://mkc1.digitaloceanspaces.com", environment.fetch("clear").fetch("BACKUP_ENDPOINT")
    assert_includes environment.fetch("secret"), "BACKUP_ACCESS_KEY_ID"
    assert_includes environment.fetch("secret"), "BACKUP_SECRET_ACCESS_KEY"

    recurring = YAML.load_file(Rails.root.join("config/recurring.yml")).fetch("production").fetch("database_backup")
    assert_equal "DatabaseBackupJob", recurring.fetch("class")
    assert_equal "at 3am every day", recurring.fetch("schedule")
  end
end
