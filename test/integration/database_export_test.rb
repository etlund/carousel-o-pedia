require "test_helper"

class DatabaseExportTest < ActionDispatch::IntegrationTest
  test "only administrators with accepted terms can download the database" do
    get database_export_path
    assert_redirected_to new_session_path
    sign_in_as users(:editor)
    get database_export_path
    assert_redirected_to root_path
    sign_out
    admin = users(:admin)
    admin.update_columns(contribution_terms_version: nil, contribution_terms_accepted_at: nil)
    sign_in_as admin
    get database_export_path
    assert_redirected_to edit_contribution_agreement_path
  end

  test "administrator downloads a private SQLite snapshot" do
    sign_in_as users(:admin)
    get invitations_path
    assert_select "a[href=?]", database_export_path, text: "Download database snapshot"
    get database_export_path
    assert_response :success
    assert_equal "application/vnd.sqlite3", response.media_type
    assert_match(/attachment.*\.sqlite3/, response.headers["Content-Disposition"])
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_equal "SQLite format 3\0", response.body.byteslice(0, 16)
    Tempfile.create([ "download-test-", ".sqlite3" ]) do |file|
      file.binmode
      file.write(response.body)
      file.flush
      SQLite3::Database.new(file.path, readonly: true) do |database|
        assert_equal [ [ "ok" ] ], database.execute("PRAGMA integrity_check")
        assert_operator database.get_first_value("SELECT COUNT(*) FROM users"), :>, 0
      end
    end
  end
end
