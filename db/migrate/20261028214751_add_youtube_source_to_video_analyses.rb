class AddYoutubeSourceToVideoAnalyses < ActiveRecord::Migration[8.1]
  def change
    add_column :video_analyses, :youtube_url, :string
    add_column :video_analyses, :youtube_start_seconds, :integer, default: 0
    add_column :video_analyses, :youtube_duration_seconds, :integer, default: 60
  end
end
