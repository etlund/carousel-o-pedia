class SeatsController < ApplicationController
  include PageHistory

  EMPTY = "empty"

  before_action :set_seat
  before_action -> { authorize_edit!(@seat) }, only: %i[ edit update ]

  def show
    if (figure = @seat.figure)
      redirect_to figure, status: :found
    else
      @previous_seat_placements = @seat.placements.where.not(ended_on: nil).includes(:figure)
    end
  end

  def edit
  end

  def update
    attributes = seat_params
    choice = params.dig(:seat, :figure_id)
    figure = Figure.find(choice) if choice.present? && choice != EMPTY
    authorize_edit!(figure) if figure
    SeatEdit.new(@seat, figure, attributes:, empty: choice == EMPTY).save!
    path = @seat.carousel_deck ? deck_seat_path(@carousel, @seat.carousel_deck, @seat) : carousel_seat_path(@carousel, @seat)
    redirect_to @seat.figure || path, notice: "Saved."
  rescue ActiveRecord::RecordInvalid => error
    messages = error.record.errors.full_messages
    @seat.reload.assign_attributes(attributes)
    messages.each { @seat.errors.add(:base, _1) }
    set_available_figures
    render :edit, status: :unprocessable_entity
  end

  private
    def set_seat
      @carousel = Carousel.find_by!(slug: params[:carousel_id])
      layout = params[:deck_id] ? @carousel.carousel_decks.find(params[:deck_id]) : @carousel
      @seat = layout.seat(params[:code]) or raise ActiveRecord::RecordNotFound
      set_available_figures
    end

    def history_record = @seat

    def seat_params = params.expect(seat: %i[ rows_spanned confidence ])

    def set_available_figures
      selectable = @carousel.figures.where(draft_placeholder: false)
      selectable = selectable.or(@carousel.figures.where(id: @seat.figure&.id))
      @figures = selectable.includes(:carousel, seat: :carousel).order(:name)
    end
end
