class CarouselsController < ApplicationController
  def index
    @carousels = Carousel.includes(:maker).order(:name)
  end

  def show
    @carousel = Carousel.find_by!(slug: params[:id])
    @sections = @carousel.section_breakdown
    @totals = @carousel.category_totals(@sections)
  end
end
