namespace :users do
  desc "Reset an existing user's password and revoke their sessions: bin/rails users:reset_password EMAIL=you@example.com"
  task reset_password: :environment do
    user = User.find_by!(email_address: ENV.fetch("EMAIL").strip.downcase)
    password = ENV["PASSWORD"] || begin
      require "io/console"
      print "New password for #{user.email_address}: "
      $stdin.noecho(&:gets)&.chomp.tap { puts }
    end
    raise ArgumentError, "Use a password of at least 12 characters" if password.to_s.length < 12

    User.transaction do
      user.update!(password:)
      user.sessions.destroy_all
    end
    puts "Password reset and sessions revoked for #{user.email_address}."
  end

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
