class FiguresController < ApplicationController
  include PageHistory
  allow_unauthenticated_access only: :index

  before_action :set_figure, only: %i[ show edit update ]

  def index
    @figures = Figure.includes(:figure_type, seat: :carousel).order(:name)
  end

  def show
    @placements = @figure.placements.includes(seat: :carousel)
  end

  def new
    @figure = Figure.new
  end

  def create
    @figure = Figure.new(figure_params)
    if @figure.save
      redirect_to @figure, notice: "Figure added. Put it on a carousel from a seat's edit page."
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
      params.expect(figure: %i[ name short_name figure_type_id mount description carver_id year_carved sponsor body ])
    end
end
