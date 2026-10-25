class AllowUnknownCarouselLayouts < ActiveRecord::Migration[8.1]
  def change
    change_column_null :carousels, :sections_count, true
    change_column_null :carousels, :rows_count, true
    change_column_null :carousels, :rotation, true
    change_column_default :carousels, :rotation, from: "counterclockwise", to: nil
  end
end
