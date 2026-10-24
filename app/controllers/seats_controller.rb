class SeatsController < ApplicationController
  include PageHistory

  EMPTY = "empty"

  before_action :set_seat

  def show
    @placements = @seat.placements.includes(figure: :figure_type)
  end

  def edit
  end

  def update
    choice = params.dig(:seat, :figure_id)
    Seat.transaction do
      @seat.update!(seat_params)
      SeatAssignment.new(@seat, Figure.find_by(id: choice), empty: choice == EMPTY).save!
    end
    redirect_to carousel_seat_path(@carousel, @seat), notice: "Saved."
  rescue ActiveRecord::RecordInvalid
    render :edit, status: :unprocessable_entity
  end

  private
    def set_seat
      @carousel = Carousel.find_by!(slug: params[:carousel_id])
      @seat = @carousel.seat(params[:code]) or raise ActiveRecord::RecordNotFound
    end

    def history_record = @seat

    def seat_params = params.expect(seat: %i[ rows_spanned confidence ])
end
