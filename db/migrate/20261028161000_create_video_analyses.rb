class CreateVideoAnalyses < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :can_analyze_videos, :boolean, null: false, default: false

    create_table :video_analyses do |t|
      t.references :carousel, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "queued"
      t.json :draft, null: false, default: {}
      t.text :error_message
      t.string :model
      t.integer :frames_count
      t.integer :input_tokens
      t.integer :output_tokens
      t.datetime :started_at
      t.datetime :finished_at
      t.datetime :applied_at
      t.timestamps
    end
    add_check_constraint :video_analyses, "status IN ('queued', 'processing', 'complete', 'failed')",
      name: "video_analyses_status"
  end
end
