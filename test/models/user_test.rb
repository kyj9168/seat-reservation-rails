require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "normalizes username and email" do
    user = User.new(
      name: "사용자",
      username: "  Mixed_User ",
      email_address: "  Mixed@Example.COM ",
      password: "password123!"
    )

    assert user.valid?
    assert_equal "mixed_user", user.username
    assert_equal "mixed@example.com", user.email_address
  end
end
