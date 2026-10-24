class MakersController < ApplicationController
  include PageHistory
  allow_unauthenticated_access only: :index

  before_action :set_maker, only: %i[ show edit update ]

  def index
    @makers = Maker.order(:name)
  end

  def show
  end

  def new
    @maker = Maker.new
  end

  def create
    @maker = Maker.new(maker_params)
    if @maker.save
      redirect_to @maker, notice: "Maker added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @maker.update(maker_params)
      redirect_to @maker, notice: "Saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_maker
      @maker = Maker.find_by!(slug: params[:id])
    end

    def history_record = Maker.find_by!(slug: params[:id])

    def maker_params = params.expect(maker: %i[ name kind years_active body ])
end
