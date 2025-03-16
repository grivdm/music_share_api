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

ActiveRecord::Schema[8.0].define(version: 2025_03_15_234817) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "conversion_requests", force: :cascade do |t|
    t.string "source_platform", null: false
    t.string "source_url", null: false
    t.boolean "successful", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_conversion_requests_on_created_at"
    t.index ["source_platform"], name: "index_conversion_requests_on_source_platform"
  end

  create_table "platform_tracks", force: :cascade do |t|
    t.bigint "track_id", null: false
    t.string "platform", null: false
    t.string "platform_id", null: false
    t.string "url", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["platform", "platform_id"], name: "index_platform_tracks_on_platform_and_platform_id", unique: true
    t.index ["track_id", "platform"], name: "index_platform_tracks_on_track_id_and_platform", unique: true
    t.index ["track_id"], name: "index_platform_tracks_on_track_id"
  end

  create_table "tracks", force: :cascade do |t|
    t.string "isrc", null: false
    t.string "title", null: false
    t.string "artist", null: false
    t.string "album"
    t.integer "duration"
    t.integer "release_year"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["artist", "title"], name: "index_tracks_on_artist_and_title"
    t.index ["isrc"], name: "index_tracks_on_isrc", unique: true
  end

  add_foreign_key "platform_tracks", "tracks"
end
