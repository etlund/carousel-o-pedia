class LayoutDraftsController < ApplicationController
  before_action :set_carousel
  before_action -> { authorize_edit!(@carousel) }

  def new
    attributes = params[:layout_draft].present? ? draft_params : LayoutDraft.sketch_defaults_for(@layout)
    @draft = LayoutDraft.new(@layout, attributes)
  end

  def preview
    @draft = LayoutDraft.new(@layout, draft_params)
    if @draft.valid?
      render :preview
    else
      render :new, status: :unprocessable_entity
    end
  end

  def create
    @draft, snapshot = LayoutDraft.from_preview(@layout, params.expect(:preview_token))
    added = @draft.apply!(expected_snapshot: snapshot)
    redirect_to @carousel, notice: "Created a provisional seating layout with #{added} #{"draft figure".pluralize(added)}. All placements are best readings."
  rescue LayoutDraft::Conflict => error
    redirect_to new_carousel_layout_draft_path(@carousel, deck_id: params[:deck_id]), alert: error.message
  rescue ActiveModel::ValidationError
    render :new, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => error
    @draft.errors.add(:base, "Nothing was saved. #{error.message}")
    render :new, status: :unprocessable_entity
  end

  private
    def set_carousel
      @carousel = Carousel.find_by!(slug: params[:carousel_id])
      @layout = params[:deck_id].present? ? @carousel.carousel_decks.find(params[:deck_id]) : @carousel
    end

    def draft_params
      params.expect(layout_draft: %i[ sections_count rows_count figure_type_id mount chariot_type_id
        chariot_seats chariot_rows_spanned empty_seats source_notes input_mode horses_count other_animals_count chariots_count ])
    end
end
