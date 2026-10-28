# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_28_214751) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "carousels", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "city"
    t.string "region"
    t.string "country"
    t.string "venue"
    t.string "status", default: "operating", null: false
    t.integer "year_built"
    t.integer "year_opened"
    t.integer "maker_id"
    t.integer "sections_count"
    t.integer "rows_count"
    t.string "rotation"
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "official_url"
    t.string "wikipedia_url"
    t.text "other_links"
    t.integer "published_horses_count"
    t.integer "published_other_animals_count"
    t.integer "published_chariots_count"
    t.text "summary_sources"
    t.string "street_address"
    t.string "postal_code"
    t.text "address_sources"
    t.json "ring_details", default: {}, null: false
    t.text "other_names"
    t.boolean "layout_provisional", default: false, null: false
    t.index ["maker_id"], name: "index_carousels_on_maker_id"
    t.index ["slug"], name: "index_carousels_on_slug", unique: true
  end

  create_table "figure_types", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "category", null: false
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_figure_types_on_slug", unique: true
  end

  create_table "figures", force: :cascade do |t|
    t.string "name", null: false
    t.string "short_name"
    t.string "slug", null: false
    t.integer "figure_type_id", null: false
    t.string "mount"
    t.text "description"
    t.integer "carver_id"
    t.integer "year_carved"
    t.string "sponsor"
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "carousel_id", null: false
    t.index ["carousel_id"], name: "index_figures_on_carousel_id"
    t.index ["carver_id"], name: "index_figures_on_carver_id"
    t.index ["figure_type_id"], name: "index_figures_on_figure_type_id"
    t.index ["slug"], name: "index_figures_on_slug", unique: true
  end

  create_table "invitations", force: :cascade do |t|
    t.string "email_address"
    t.string "token"
    t.integer "invited_by_id", null: false
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "access_scope", default: "site_wide", null: false
    t.integer "editable_carousel_id"
    t.index ["editable_carousel_id"], name: "index_invitations_on_editable_carousel_id"
    t.index ["invited_by_id"], name: "index_invitations_on_invited_by_id"
    t.index ["token"], name: "index_invitations_on_token", unique: true
    t.check_constraint "access_scope = 'carousel' OR editable_carousel_id IS NULL", name: "invitations_editable_carousel_scope"
    t.check_constraint "access_scope IN ('site_wide', 'carousel')", name: "invitations_access_scope"
  end

  create_table "makers", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "kind"
    t.string "years_active"
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_makers_on_slug", unique: true
  end

  create_table "placements", force: :cascade do |t|
    t.integer "figure_id", null: false
    t.integer "seat_id", null: false
    t.date "started_on"
    t.date "ended_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["figure_id"], name: "index_placements_on_figure_id"
    t.index ["seat_id"], name: "index_placements_on_seat_id"
  end

  create_table "seats", force: :cascade do |t|
    t.integer "carousel_id", null: false
    t.integer "section", null: false
    t.string "row", null: false
    t.integer "rows_spanned", default: 1, null: false
    t.string "state", default: "filled", null: false
    t.string "confidence", default: "best_reading", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["carousel_id", "section", "row"], name: "index_seats_on_carousel_id_and_section_and_row", unique: true
    t.index ["carousel_id"], name: "index_seats_on_carousel_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name", default: "", null: false
    t.string "role", default: "editor", null: false
    t.datetime "suspended_at"
    t.string "contribution_terms_version"
    t.datetime "contribution_terms_accepted_at"
    t.string "access_scope", default: "site_wide", null: false
    t.integer "editable_carousel_id"
    t.boolean "can_analyze_videos", default: false, null: false
    t.index ["editable_carousel_id"], name: "index_users_on_editable_carousel_id"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.check_constraint "access_scope = 'carousel' OR editable_carousel_id IS NULL", name: "users_editable_carousel_scope"
    t.check_constraint "access_scope IN ('site_wide', 'carousel')", name: "users_access_scope"
  end

  create_table "versions", force: :cascade do |t|
    t.string "whodunnit"
    t.datetime "created_at"
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.string "event", null: false
    t.text "object", limit: 1073741823
    t.text "object_changes", limit: 1073741823
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  create_table "video_analyses", force: :cascade do |t|
    t.integer "carousel_id", null: false
    t.integer "user_id", null: false
    t.string "status", default: "queued", null: false
    t.json "draft", default: {}, null: false
    t.text "error_message"
    t.string "model"
    t.integer "frames_count"
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "applied_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "estimated_cost_usd", precision: 12, scale: 8
    t.string "youtube_url"
    t.integer "youtube_start_seconds", default: 0
    t.integer "youtube_duration_seconds", default: 60
    t.index ["carousel_id"], name: "index_video_analyses_on_carousel_id"
    t.index ["user_id"], name: "index_video_analyses_on_user_id"
    t.check_constraint "status IN ('queued', 'processing', 'complete', 'failed')", name: "video_analyses_status"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "carousels", "makers"
  add_foreign_key "figures", "carousels"
  add_foreign_key "figures", "figure_types"
  add_foreign_key "figures", "makers", column: "carver_id"
  add_foreign_key "invitations", "carousels", column: "editable_carousel_id"
  add_foreign_key "invitations", "users", column: "invited_by_id"
  add_foreign_key "placements", "figures"
  add_foreign_key "placements", "seats"
  add_foreign_key "seats", "carousels"
  add_foreign_key "sessions", "users"
  add_foreign_key "users", "carousels", column: "editable_carousel_id"
  add_foreign_key "video_analyses", "carousels"
  add_foreign_key "video_analyses", "users"
end
