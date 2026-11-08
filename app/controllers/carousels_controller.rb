class CarouselsController < ApplicationController
  include PageHistory
  include Pagy::Method
  class_attribute :per_page, default: 12
  allow_unauthenticated_access only: :index

  before_action :set_carousel, only: %i[ show edit update ]
  before_action -> { authorize_edit!(@carousel) }, only: %i[ edit update ]
  before_action -> { raise User::AccessDenied unless current_user.can_create_carousel? }, only: %i[ new create ]

  def index
    @total_carousels = Carousel.count
    @region_counts = Carousel.where.not(region: [ nil, "" ]).group(:region).order(:region).count
    @country_counts = Carousel.where.not(country: [ nil, "" ]).group(:country).order(:country).count
    @query = params.expect(:q).strip.presence if params[:q].present?
    @selected_region = params.expect(:region).strip.presence if params[:region].present?
    @selected_country = params.expect(:country).strip.presence if params[:country].present?
    @sort = params[:sort].present? ? params.expect(:sort).strip.presence : nil
    @sort ||= "completeness"
    @sort = "completeness" if @sort == "confirmed_seats"
    raise ActionController::BadRequest, "Unknown carousel sort order" unless %w[ name updated completeness ].include?(@sort)

    if @selected_region && !@region_counts.key?(@selected_region)
      raise ActiveRecord::RecordNotFound, "Unknown state or region"
    end
    if @selected_country && !@country_counts.key?(@selected_country)
      raise ActiveRecord::RecordNotFound, "Unknown country"
    end

    @carousels = Carousel.includes(:maker, :carousel_decks, all_seats: { current_placement: { figure: :figure_type } }, seats: { current_placement: { figure: :figure_type } })
    @carousels = @carousels.recently_updated if @sort == "updated"
    @carousels = @carousels.most_complete if @sort == "completeness"
    @carousels = @carousels.order(:name, :id)
    if @query
      @carousels = @carousels.where("LOWER(name) LIKE :query ESCAPE '!' OR LOWER(other_names) LIKE :query ESCAPE '!'",
        query: "%#{Carousel.sanitize_sql_like(@query.downcase, "!")}%")
    end
    @carousels = @carousels.where(region: @selected_region) if @selected_region
    @carousels = @carousels.where(country: @selected_country) if @selected_country
    @pagy, @carousels = pagy(:offset, @carousels, limit: per_page)
    @category_counts = Placement.current.joins(:seat, figure: :figure_type)
      .where(seats: { carousel_id: @carousels.map(&:id) })
      .group("seats.carousel_id", "figure_types.category").count
  end

  def show
    @sections = @carousel.section_breakdown
    @totals = @carousel.category_totals(@sections)
  end

  def new
    @carousel = Carousel.new
  end

  def create
    @carousel = current_user.create_carousel(carousel_params)
    if @carousel.persisted?
      notice = if @carousel.layout_known?
        "Carousel added. Every seat starts as unknown; click one on the chart to fill it in."
      else
        "Carousel added. Its seating layout has not been recorded yet."
      end
      redirect_to @carousel, notice:
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    lead_seat = @carousel.seats.find_by(id: params.dig(:carousel, :lead_seat_id))
    @carousel.assign_attributes(carousel_params)
    if lead_seat && @carousel.sections_count && lead_seat.section > @carousel.sections_count
      @carousel.errors.add(:base, "Choose a lead figure in a section that remains in the layout")
      render :edit, status: :unprocessable_entity
    elsif @carousel.save
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

    def carousel_params
      permitted = %i[ name other_names street_address city region postal_code country address_sources venue status year_built year_opened maker_id rotation body official_url wikipedia_url other_links
        music_type music_description
        published_horses_count published_other_animals_count published_chariots_count summary_sources decks_count sections_count rows_count ]
      if @carousel&.layout_known?
        permitted << :layout_provisional
      end
      permitted << { ring_details: ("A"..).first(Carousel::MAX_ROWS).index_with { Carousel::RING_FIELDS } }
      params.expect(carousel: permitted)
    end
end
