class CarouselCsvsController < ApplicationController
  before_action :require_admin

  def show
  end

  def export
    send_data CarouselCsv.export, type: "text/csv; charset=utf-8",
      filename: "carousels-#{Date.current.iso8601}.csv"
  end

  def preview
    upload = params[:file]
    text = params[:csv_text].to_s
    if upload.present? && text.present?
      raise CarouselCsv::Error, "Choose a file or paste CSV, not both."
    end
    if upload.present? && !upload.respond_to?(:read)
      raise CarouselCsv::Error, "Choose a CSV file."
    end

    @import = CarouselCsv.new(upload.present? ? upload.read(CarouselCsv::MAX_BYTES + 1) : text)
    @preview_token = @import.preview_token(current_user) if @import.valid?
    render :preview, status: @import.valid? ? :ok : :unprocessable_entity
  rescue CarouselCsv::Error => error
    flash.now[:alert] = error.message
    render :show, status: :unprocessable_entity
  end

  def apply
    counts = CarouselCsv.apply!(params.expect(:preview_token), current_user)
    redirect_to carousel_csv_path, notice: "Import complete: #{counts[:created]} created, #{counts[:updated]} updated, #{counts[:unchanged]} unchanged."
  rescue CarouselCsv::Error, ActiveRecord::RecordInvalid => error
    redirect_to carousel_csv_path, alert: "Nothing was saved. #{error.message}"
  end
end
