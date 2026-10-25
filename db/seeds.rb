# Detailed inventory seeds restore their data; the directory seed only adds missing carousels.
Dir[Rails.root.join("db/seeds/*.rb")].sort.each { |file| load file }
