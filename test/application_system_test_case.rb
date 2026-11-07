require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    # Chrome's compromised-password prompt can intercept input after fixture logins.
    options.add_preference("profile.password_manager_leak_detection", false)
  end

  def visit(...)
    super.tap do
      wait_for_page_ready
    end
  end

  %i[ click_link click_button click_on fill_in select check uncheck ].each do |action|
    define_method(action) do |*args, **options, &block|
      wait_for_page_ready
      super(*args, **options, &block)
    end
  end

  private
    def wait_for_page_ready
      # A cached Turbo preview may expose controls that the final response replaces.
      page.document.assert_selector("html:not([data-turbo-preview]):not([aria-busy='true'])") do
        page.evaluate_script("Boolean(window.Turbo && window.Stimulus) && document.fonts.status === 'loaded'")
      end
    end
end
