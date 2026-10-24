class FiguresController < ApplicationController
  include PageHistory
  allow_unauthenticated_access only: :index

  before_action :set_figure, only: %i[ show edit update ]

  def index
    @carousels = Carousel.order(:name)
    @figure_types = FigureType.order(:name)
    @selected_carousel = Carousel.find(params.expect(:carousel_id)) if params[:carousel_id].present?
    @selected_type = FigureType.find(params.expect(:figure_type_id)) if params[:figure_type_id].present?
    @figures = Figure.includes(:figure_type, :carousel, seat: :carousel).order(:name)
    @figures = @figures.where(carousel: @selected_carousel) if @selected_carousel
    @figures = @figures.where(figure_type: @selected_type) if @selected_type
  end

  def show
    @placements = @figure.placements.includes(seat: :carousel)
  end

  def new
    @figure = Figure.new
    @figure.carousel = Carousel.find(params.expect(:carousel_id)) if params[:carousel_id].present?
  end

  def create
    @figure = Figure.new(figure_params)
    if @figure.save
      redirect_to @figure, notice: "Figure added. Assign a seat from the carousel's seat edit page."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @figure.update(figure_params)
      redirect_to @figure, notice: "Saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_figure
      @figure = Figure.find_by!(slug: params[:id])
    end

    def history_record = Figure.find_by!(slug: params[:id])

    def figure_params
      params.expect(figure: %i[ name short_name carousel_id figure_type_id mount description carver_id year_carved sponsor body ])
    end
end
