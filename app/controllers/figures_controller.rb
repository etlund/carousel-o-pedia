class FiguresController < ApplicationController
  def index
    @figures = Figure.includes(:figure_type, seat: :carousel).order(:name)
  end

  def show
    @figure = Figure.find_by!(slug: params[:id])
    @placements = @figure.placements.includes(seat: :carousel)
  end
end
