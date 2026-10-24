class SeatsController < ApplicationController
  def show
    @carousel = Carousel.find_by!(slug: params[:carousel_id])
    @seat = @carousel.seat(params[:code]) or raise ActiveRecord::RecordNotFound
    @placements = @seat.placements.includes(figure: :figure_type)
  end
end
