class FigureTypesController < ApplicationController
  def index
    @figure_types = FigureType.left_joins(:figures).group(:id).select("figure_types.*, COUNT(figures.id) AS figures_count").order(:category, :name)
  end

  def show
    @figure_type = FigureType.find_by!(slug: params[:id])
    @figures = @figure_type.figures.includes(seat: :carousel).order(:name)
  end
end
