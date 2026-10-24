# A local admin account so editing works right after bin/setup. Development only.
if Rails.env.development?
  User.find_or_create_by!(email_address: "admin@example.com") do |user|
    user.name = "Local Admin"
    user.role = "admin"
    user.password = "carousel"
  end
end
