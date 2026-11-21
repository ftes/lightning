defmodule LightningE2E.Pages.Workflows do
  @moduledoc "Port of `pages/workflows.page.ts`: the workflows listing page."
  alias LightningE2E.Pages.LiveView
  alias Playwright.{Expect, Locator, Page}

  @create_new_workflow_button ~s|button:has-text("Create new workflow")|

  def click_new_workflow(page) do
    LiveView.wait_for_connected(page)

    create_button = Page.locator(page, @create_new_workflow_button)
    Expect.to_be_visible!(create_button)

    # Wait for Phoenix event handlers to be attached to the button
    LiveView.wait_for_event_attached(page, create_button, "click")

    Locator.click!(create_button)
  end

  @doc "Navigate to a workflow by clicking its row in the workflows list."
  def navigate_to_workflow(page, workflow_name) do
    LiveView.wait_for_connected(page)

    # The <tr> has phx-click and contains an element with aria-label matching the workflow name
    workflow_row =
      page
      |> Page.locator("tr")
      |> Locator.filter(has: Page.get_by_label(page, workflow_name))

    Expect.to_be_visible!(workflow_row)

    LiveView.wait_for_event_attached(page, workflow_row, "click")

    Locator.click!(workflow_row)

    Page.wait_for_load_state!(page, :networkidle)
  end
end
