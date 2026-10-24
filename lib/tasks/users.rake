namespace :users do
  desc "Create the first admin, who can then invite editors: bin/rails users:create_admin EMAIL=you@example.com NAME='Your Name'"
  task create_admin: :environment do
    email, name = ENV.fetch("EMAIL"), ENV.fetch("NAME")
    password = ENV["PASSWORD"] || begin
      require "io/console"
      print "Password for #{email}: "
      $stdin.noecho(&:gets).chomp.tap { puts }
    end

    user = User.create!(email_address: email, name:, password:, role: "admin")
    puts "Created admin #{user.name} <#{user.email_address}>."
  end
end
