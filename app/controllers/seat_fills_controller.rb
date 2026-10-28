class SeatFillsController < ApplicationController
  before_action :set_carousel
  before_action -> { authorize_edit!(@carousel) }

  def new
    attributes = params[:seat_fill].present? ? seat_fill_params : {
      figure_type_id: FigureType.find_by(name: "Horse")&.id, mount: "jumper"
    }
    @fill = SeatFill.new(@carousel, attributes)
  end

  def preview
    @fill = SeatFill.new(@carousel, seat_fill_params)
    if @fill.valid?
      render :preview
    else
      render :new, status: :unprocessable_entity
    end
  end

  def create
    @fill, snapshot = SeatFill.from_preview(@carousel, params.expect(:preview_token))
    added = @fill.apply!(expected_snapshot: snapshot)
    redirect_to @carousel, notice: "Added #{added} #{"draft figure".pluralize(added)}. All new placements are best readings; existing figures and empty seats were left unchanged."
  rescue SeatFill::Conflict => error
    redirect_to new_carousel_seat_fill_path(@carousel), alert: error.message
  rescue ActiveModel::ValidationError
    render :new, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => error
    @fill.errors.add(:base, "Nothing was saved. #{error.message}")
    render :new, status: :unprocessable_entity
  end

  private
    def set_carousel
      @carousel = Carousel.find_by!(slug: params[:carousel_id])
    end

    def seat_fill_params
      params.expect(seat_fill: %i[ figure_type_id mount source_notes ])
    end
end
