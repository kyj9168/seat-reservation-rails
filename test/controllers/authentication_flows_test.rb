require "test_helper"

class AuthenticationFlowsTest < ActionDispatch::IntegrationTest
  test "registers a user and starts a session" do
    assert_difference([ "User.count", "Session.count" ], 1) do
      post registration_url, params: {
        user: {
          name: "신규 사용자",
          username: "new_user",
          email_address: "new@example.com",
          password: "password123!",
          password_confirmation: "password123!"
        }
      }
    end

    assert_redirected_to root_url
  end

  test "logs in with username and password" do
    post session_url, params: { username: users(:one).username, password: "password123!" }

    assert_redirected_to root_url
    assert_equal users(:one), Session.order(:created_at).last.user
  end

  test "finds a masked username" do
    post username_lookup_url, params: {
      name: users(:one).name,
      email_address: users(:one).email_address
    }

    assert_response :success
    assert_select ".lookup-result", text: /use\*+/
  end

  test "sends a password reset email" do
    assert_enqueued_emails 1 do
      post password_url, params: { email_address: users(:one).email_address }
    end

    assert_redirected_to new_session_url
  end

  test "resets a password and invalidates existing sessions" do
    user = users(:one)
    sign_in_as(user)
    token = user.password_reset_token

    patch update_password_url(token), params: {
      password: "new_password123!",
      password_confirmation: "new_password123!"
    }

    assert_redirected_to new_session_url
    assert_empty user.sessions.reload
    assert user.reload.authenticate("new_password123!")
  end
end
