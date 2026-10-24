require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "renders Markdown headings, lists, emphasis and source links" do
    render html: wiki_body(<<~MD)
      ## History

      A **community-built** carousel with *hand-carved* figures.

      ## Sources

      - [Official history](https://www.missoulacarousel.org/building-a-community-dream-a-carousel-for-missoula/)
      - https://carousels.org/psp/Missoula/
    MD

    assert_select "h2", text: "History"
    assert_select "h2", text: "Sources"
    assert_select "p strong", "community-built"
    assert_select "p em", "hand-carved"
    assert_select "ul li", 2
    assert_select "li a[href=?]", "https://www.missoulacarousel.org/building-a-community-dream-a-carousel-for-missoula/", text: "Official history"
    assert_select "li a[href=?]", "https://carousels.org/psp/Missoula/"
  end

  test "preserves plain text paragraphs, line breaks and safe inline HTML" do
    render html: wiki_body("First line\nSecond line\n\nA <strong>separate</strong> paragraph.")

    assert_select "p", 2
    assert_select "p br", 1
    assert_select "strong", "separate"
  end

  test "renders fenced code as text rather than HTML" do
    render html: wiki_body("```html\n<script>alert('example')</script>\n```")

    assert_select "pre code", "<script>alert('example')</script>"
    assert_select "script", 0
  end

  test "sanitizes raw HTML and dangerous link protocols after rendering Markdown" do
    render html: wiki_body(<<~MD)
      ## Safe heading

      <script>alert('unsafe')</script>

      <img src="https://example.com/pony.png" onerror="alert('unsafe')">

      [Unsafe source](javascript:alert%281%29)

      <a href="javascript:alert('unsafe')" onclick="alert('unsafe')">Unsafe HTML link</a>
    MD

    assert_select "h2", "Safe heading"
    assert_select "script", 0
    assert_select "[onerror], [onclick]", 0
    assert_select "a[href^='javascript:']", 0
    assert_select "a", text: "Unsafe source"
    assert_select "a", text: "Unsafe HTML link"
  end

  test "does not render blank page text" do
    assert_nil wiki_body(nil)
    assert_nil wiki_body("")
    assert_nil wiki_body(" \n ")
  end
end
