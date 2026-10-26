namespace :carousels do
  desc "Import only Elitch Gardens research, preserving existing wiki data"
  task import_elitch_gardens: :environment do
    slug = "elitch-gardens-carousel-denver"
    before = Figure.where(carousel: Carousel.where(slug:)).count
    Carousel.transaction do
      OperatingCarouselImport.call(slug:)
      load Rails.root.join("db/seeds/us_researched_elitch_gardens.rb")
    end
    carousel = Carousel.find_by!(slug:)
    puts "Elitch Gardens import complete (#{Rails.env})."
    puts "Published totals: #{carousel.published_horses_count} horses, " \
      "#{carousel.published_other_animals_count} other animals, #{carousel.published_chariots_count} chariots."
    puts "Inventory: #{carousel.figures.count} figures (#{carousel.figures.count - before} added); existing figures and placements preserved."
    puts "Existing values take precedence. No seating positions inferred."
  end
end
