require "application_system_test_case"

class SpendsTest < ApplicationSystemTestCase
  setup do
    @spend = spends(:one)
  end

  test "visiting the index" do
    visit spends_url
    assert_selector "h1", text: "Spends"
  end

  test "creating a Spend" do
    visit spends_url
    click_on "New Spend"

    fill_in "Card", with: @spend.card_id
    fill_in "Description", with: @spend.description
    check "Paid" if @spend.paid
    fill_in "Value", with: @spend.value
    click_on "Create Spend"

    assert_text "Spend was successfully created"
    click_on "Back"
  end

  test "updating a Spend" do
    visit spends_url
    click_on "Edit", match: :first

    fill_in "Card", with: @spend.card_id
    fill_in "Description", with: @spend.description
    check "Paid" if @spend.paid
    fill_in "Value", with: @spend.value
    click_on "Update Spend"

    assert_text "Spend was successfully updated"
    click_on "Back"
  end

  test "destroying a Spend" do
    visit spends_url
    page.accept_confirm do
      click_on "Destroy", match: :first
    end

    assert_text "Spend was successfully destroyed"
  end
end
