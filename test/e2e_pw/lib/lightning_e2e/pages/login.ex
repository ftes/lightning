defmodule LightningE2E.Pages.Login do
  @moduledoc "Port of `pages/login.page.ts`: user authentication interactions."
  alias Playwright.{Expect, Locator, Page}

  @login_form "#login form"
  @email_input ~s|input[name="user[email]"]|
  @password_input ~s|input[name="user[password]"]|
  @submit_button ~s|button[type="submit"]|
  @login_button ~s|button:has-text("Log in")|

  def login_form_visible?(page) do
    page |> Page.locator(@login_form) |> Locator.is_visible!()
  end

  @doc "Fill in login credentials and submit the form."
  def login(page, email, password) do
    page |> Page.locator(@login_form) |> Expect.to_be_visible!()

    page |> Page.locator(@email_input) |> Locator.fill!(email)
    page |> Page.locator(@password_input) |> Locator.fill!(password)

    # Try both possible button selectors
    submit_button = Page.locator(page, @submit_button)
    login_button = Page.locator(page, @login_button)

    if Locator.is_visible!(submit_button) do
      Locator.click!(submit_button)
    else
      Locator.click!(login_button)
    end

    Page.wait_for_load_state!(page, :networkidle)
  end

  @doc "Perform login if the login form is visible, otherwise skip."
  def login_if_needed(page, email, password) do
    if login_form_visible?(page), do: login(page, email, password)
  end
end
