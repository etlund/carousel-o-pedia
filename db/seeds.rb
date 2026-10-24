# Seed data is safe to load more than once.
Dir[Rails.root.join("db/seeds/*.rb")].sort.each { |file| load file }
