require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "current agreement requires both a timestamp and the exact terms version" do
    user = users(:editor)
    assert user.contribution_terms_accepted?
    user.contribution_terms_accepted_at = nil
    assert_not user.contribution_terms_accepted?
    user.contribution_terms_accepted_at = Time.current
    user.contribution_terms_version = "older-terms"
    assert_not user.contribution_terms_accepted?
  end

  test "suspension cannot disable an administrator or revoke their sessions" do
    admin = users(:admin)
    session = admin.sessions.create!
    assert_raises ActiveRecord::RecordInvalid do
      admin.suspend!
    end
    assert_not admin.reload.suspended?
    assert admin.sessions.exists?(session.id)
  end

  test "existing editors and admins retain site-wide access" do
    [ users(:editor), users(:admin) ].each do |user|
      assert_equal "site_wide", user.access_scope
      assert user.site_wide_access?
      assert user.can_create_carousel?
      assert user.can_edit?(build_carousel)
      assert user.can_edit?(Maker.new)
      assert user.can_edit?(FigureType.new)
    end
  end

  test "stale user instances cannot consume the new-carousel permission twice" do
    user = users(:editor)
    user.update!(access_scope: "carousel")
    stale_user = User.find(user.id)
    carousel = user.create_carousel(name: "First blank carousel")
    assert carousel.persisted?
    assert_equal carousel.id, user.reload.editable_carousel_id
    assert_no_difference "Carousel.count" do
      assert_raises User::AccessDenied do
        stale_user.create_carousel(name: "Second blank carousel")
      end
    end
  end

  test "suspended editors cannot create or edit even their assigned carousel" do
    user = users(:editor)
    carousel = build_carousel
    user.update!(access_scope: "carousel", editable_carousel: carousel, suspended_at: Time.current)
    assert_not user.can_edit?(carousel)
    assert_not user.can_create_carousel?
    assert_empty user.editable_carousels
    user.editable_carousel = nil
    assert_not user.can_create_carousel?
  end
end
