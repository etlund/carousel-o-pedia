class CarouselsController < ApplicationController
  include PageHistory
  allow_unauthenticated_access only: :index

  before_action :set_carousel, only: %i[ show edit update ]

  def index
    @carousels = Carousel.includes(:maker).order(:name)
    @category_counts = Placement.current.joins(:seat, figure: :figure_type)
      .group("seats.carousel_id", "figure_types.category").count
  end

  def show
    @sections = @carousel.section_breakdown
    @totals = @carousel.category_totals(@sections)
  end

  def new
    @carousel = Carousel.new(rows_count: 3)
  end

  def create
    @carousel = Carousel.new(carousel_params)
    if @carousel.save
      redirect_to @carousel, notice: "Carousel added. Every seat starts as unknown; click one on the chart to fill it in."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    lead_seat = @carousel.seats.find_by(id: params.dig(:carousel, :lead_seat_id))
    if @carousel.update(carousel_params)
      @carousel.renumber_from!(lead_seat) if lead_seat
      redirect_to @carousel, notice: "Saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_carousel
      @carousel = Carousel.find_by!(slug: params[:id])
    end

    def history_record = Carousel.find_by!(slug: params[:id])

    # The platform's size is fixed once seats exist; changing it would orphan seat codes.
    def carousel_params
      permitted = %i[ name city region country venue status year_built year_opened maker_id rotation body ]
      permitted += %i[ sections_count rows_count ] if @carousel.nil? || @carousel.new_record?
      params.expect(carousel: permitted)
    end
end
