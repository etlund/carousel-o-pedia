module SeatingPreview
  extend ActiveSupport::Concern

  def preview_token
    self.class.verifier.generate(
      { "carousel_id" => @carousel.id, "attributes" => attributes, "snapshot" => snapshot },
      purpose: self.class.model_name.param_key.dasherize, expires_in: 1.hour)
  end

  class_methods do
    def from_preview(carousel, token)
      payload = verifier.verified(token, purpose: model_name.param_key.dasherize)
      unless payload && payload["carousel_id"] == carousel.id
        raise self::Conflict, "This preview is invalid or has expired. Preview the draft again."
      end

      [ new(carousel, payload.fetch("attributes")), payload.fetch("snapshot") ]
    end

    def verifier = Rails.application.message_verifier(model_name.param_key.dasherize)
  end
end
