require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  def visit(...)
    super.tap do
      # Web fonts can move links and checkboxes after they first become visible.
      page.evaluate_async_script("document.fonts.ready.then(() => arguments[0](true))")
    end
  end
end
