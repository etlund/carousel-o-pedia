class CarouselDecksController < ApplicationController
  include PageHistory
  before_action :set_carousel
  before_action :set_deck, only: %i[ show edit update history ]
  before_action -> { authorize_edit!(@carousel) }, only: %i[ new create edit update ]

  def show
  end

  def new
    @deck = @carousel.carousel_decks.new(position: (@carousel.carousel_decks.maximum(:position) || 0) + 1)
  end

  def create
    @deck = @carousel.carousel_decks.new(deck_params)
    if @deck.save
      redirect_to carousel_deck_path(@carousel, @deck), notice: "Deck added. Unknown geometry and counts were left unassigned."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @deck.update(deck_params)
      redirect_to carousel_deck_path(@carousel, @deck), notice: "Saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_carousel
      @carousel = Carousel.find_by!(slug: params[:carousel_id])
    end

    def set_deck
      @deck = @carousel.carousel_decks.find(params[:id])
    end

    def history_record = @deck

    def deck_params
      params.expect(carousel_deck: %i[ name position sections_count rows_count layout_provisional
        published_horses_count published_other_animals_count published_chariots_count summary_sources ])
    end
end
