# Seeds are authoritative: reloading restores seeded attributes and placements.
Dir[Rails.root.join("db/seeds/*.rb")].sort.each { |file| load file }
