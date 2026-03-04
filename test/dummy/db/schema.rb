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

ActiveRecord::Schema[8.1].define(version: 5) do
  create_table "advanced_orders", force: :cascade do |t|
    t.string "title"
    t.integer "user_id"
    t.string "user_type"
  end

  create_table "posts", force: :cascade do |t|
    t.datetime "approved_at", precision: nil
    t.string "status"
    t.text "status_steps"
    t.datetime "submitted_at", precision: nil
    t.integer "submitted_by_id"
    t.string "title"
  end

  create_table "simple_orders", force: :cascade do |t|
    t.string "title"
    t.integer "user_id"
  end

  create_table "thangs", force: :cascade do |t|
    t.text "body"
    t.string "title"
  end

  create_table "things", force: :cascade do |t|
    t.text "body"
    t.boolean "boolean"
    t.datetime "created_at", null: false
    t.date "date"
    t.datetime "datetime", precision: nil
    t.decimal "decimal"
    t.integer "integer"
    t.datetime "job_ended_at", precision: nil
    t.text "job_error"
    t.datetime "job_started_at", precision: nil
    t.string "job_status"
    t.integer "price"
    t.datetime "published_end_at", precision: nil
    t.datetime "published_start_at", precision: nil
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "thongs", force: :cascade do |t|
    t.text "body"
    t.string "title"
    t.text "wizard_steps"
  end

  create_table "users", force: :cascade do |t|
    t.string "alternate_email"
    t.string "email"
    t.string "first_name"
    t.string "last_name"
  end
end
