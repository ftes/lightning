defmodule LightningE2E.Pages.Projects do
  @moduledoc "Port of `pages/projects.page.ts`: the projects listing page."
  alias LightningE2E.Pages.LiveView
  alias Playwright.{Expect, Locator, Page}

  @doc "Navigate to a specific project's workflows page."
  def navigate_to_project(page, project_name) do
    project_row =
      page
      |> Page.get_by_role(:cell, name: project_name)
      |> Locator.locator("..")

    LiveView.wait_for_event_attached(page, project_row, "click")
    Expect.to_be_visible!(project_row)
    Locator.click!(project_row)
  end

  def navigate_to_projects(page) do
    LiveView.click_menu_item(page, "Projects")
    LiveView.wait_for_connected(page)
  end

  def verify_project_visible(page, project_name) do
    page
    |> Page.get_by_role(:cell, name: project_name)
    |> Expect.to_be_visible!()
  end

  def verify_projects_list_not_empty(page) do
    page |> Page.get_by_role(:cell) |> Expect.not_to_have_count!(0)
  end
end
