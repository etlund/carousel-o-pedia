ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    def load_seeds
      Rails.application.load_seed
      Carousel.find_by!(slug: "great-northern-carousel")
    end

    def create_figure(name, category: "horse", carousel: @carousel || build_carousel)
      type = FigureType.find_or_create_by!(name: category.capitalize) { _1.category = category }
      Figure.create!(name:, figure_type: type, carousel:)
    end

    def build_carousel(sections: 4, rows: 2)
      Carousel.create!(name: "Test Carousel #{SecureRandom.hex(3)}", sections_count: sections, rows_count: rows)
    end
  end
end
