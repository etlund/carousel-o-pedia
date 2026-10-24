class FigureTypesController < ApplicationController
  include PageHistory
  allow_unauthenticated_access only: :index

  before_action :set_figure_type, only: %i[ show edit update ]

  def index
    @figure_types = FigureType.left_joins(:figures).group(:id).select("figure_types.*, COUNT(figures.id) AS figures_count").order(:category, :name)
  end

  def show
    @figures = @figure_type.figures.includes(seat: :carousel).order(:name)
  end

  def new
    @figure_type = FigureType.new(category: "menagerie")
  end

  def create
    @figure_type = FigureType.new(figure_type_params)
    if @figure_type.save
      redirect_to @figure_type, notice: "Type added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @figure_type.update(figure_type_params)
      redirect_to @figure_type, notice: "Saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_figure_type
      @figure_type = FigureType.find_by!(slug: params[:id])
    end

    def history_record = FigureType.find_by!(slug: params[:id])

    def figure_type_params = params.expect(figure_type: %i[ name category body ])
end
