class AddEstimatedCostUsdToVideoAnalyses < ActiveRecord::Migration[8.1]
  def change
    add_column :video_analyses, :estimated_cost_usd, :decimal, precision: 12, scale: 8
  end
end
