require 'test_helper'

class SpendsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @spend = spends(:one)
  end

  test "should get index" do
    get spends_url
    assert_response :success
  end

  test "should get new" do
    get new_spend_url
    assert_response :success
  end

  test "should create spend" do
    assert_difference('Spend.count') do
      post spends_url, params: { spend: { card_id: @spend.card_id, description: @spend.description, paid: @spend.paid, value: @spend.value } }
    end

    assert_redirected_to spend_url(Spend.last)
  end

  test "should show spend" do
    get spend_url(@spend)
    assert_response :success
  end

  test "should get edit" do
    get edit_spend_url(@spend)
    assert_response :success
  end

  test "should update spend" do
    patch spend_url(@spend), params: { spend: { card_id: @spend.card_id, description: @spend.description, paid: @spend.paid, value: @spend.value } }
    assert_redirected_to spend_url(@spend)
  end

  test "should destroy spend" do
    assert_difference('Spend.count', -1) do
      delete spend_url(@spend)
    end

    assert_redirected_to spends_url
  end
end
