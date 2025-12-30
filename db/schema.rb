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

ActiveRecord::Schema[8.0].define(version: 2025_10_12_131945) do
  create_table "metrics", force: :cascade do |t|
    t.string "country", null: false
    t.string "metric_name", null: false
    t.decimal "metric_value", precision: 15, scale: 2
    t.integer "year", null: false
    t.string "unit"
    t.string "source"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["country", "metric_name", "year"], name: "index_metrics_on_country_and_metric_name_and_year", unique: true
    t.index ["metric_name"], name: "index_metrics_on_metric_name"
    t.index ["year"], name: "index_metrics_on_year"
  end
end
