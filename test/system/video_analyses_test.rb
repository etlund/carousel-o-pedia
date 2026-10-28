require "application_system_test_case"

class VideoAnalysesSystemTest < ApplicationSystemTestCase
  test "an authorized editor submits a YouTube segment from the analysis form" do
    carousel = build_carousel(sections: 2, rows: 2)
    visit new_session_path
    fill_in "Email", with: users(:admin).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_selector "button", text: "Sign out"
    visit new_carousel_video_analysis_path(carousel)
    assert_field "Start time (seconds)", with: "0"
    assert_field "Clip length (seconds)", with: "60"
    fill_in "YouTube link", with: "https://youtu.be/Usok6GXGavc"
    fill_in "Start time (seconds)", with: "2"
    fill_in "Clip length (seconds)", with: "20"
    click_button "Analyze video"
    assert_selector "h1", text: "Video analysis"
    assert_link "YouTube: 2s–22s", href: "https://www.youtube.com/watch?v=Usok6GXGavc&t=2"
    assert_text "The tool will retrieve the selected YouTube segment"
    analysis = carousel.video_analyses.sole
    assert analysis.queued?
    assert_empty analysis.attached_passes
  end
end
