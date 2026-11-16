defmodule LightningE2E.Pages.WorkflowCollab do
  @moduledoc """
  Port of `pages/workflow-collab.page.ts`: the React-based collaborative workflow
  editor (Yjs over Phoenix Channels).
  """
  alias Playwright.{Expect, Page}

  @collaborative_editor ~s|[data-testid="collaborative-editor"]|
  @sync_status "text=Synced"
  # Error indicators: specific error UI components, not generic text
  @error_alert ~s|[role="alert"] >> text=/error/i|
  @socket_error "text=/socket (error|disconnected)/i"

  @doc """
  Navigate directly to an existing workflow's collaborative editor and wait until
  it is loaded and synced.
  """
  def open(page, %{project_id: project_id, workflow_id: workflow_id}) do
    Page.goto!(page, "/projects/#{project_id}/w/#{workflow_id}")
    wait_for_react_component_loaded(page)
    wait_for_synced(page)
  end

  @doc "Wait for the collaborative editor React component to load and render."
  def wait_for_react_component_loaded(page) do
    # Wait for main container
    page
    |> Page.locator(@collaborative_editor)
    |> Expect.to_be_visible!(timeout: 10_000)

    # Wait for React hydration to complete
    Page.wait_for_load_state!(page, :networkidle)
  end

  @doc "Wait for the collaborative editor to reach \"Synced\" state."
  def wait_for_synced(page) do
    page |> Page.locator(@sync_status) |> Expect.to_be_visible!(timeout: 15_000)
  end

  @doc "Verify that no error states are displayed in the collaborative editor."
  def verify_no_errors(page) do
    page |> Page.locator(@error_alert) |> Expect.not_to_be_visible!()
    page |> Page.locator(@socket_error) |> Expect.not_to_be_visible!()
  end

  def container(page), do: Page.locator(page, @collaborative_editor)

  def save_button(page),
    do: Page.locator(page, ~s|[data-testid="save-workflow-button"]|)

  def save_workflow(page),
    do: page |> save_button() |> Playwright.Locator.click!()

  @doc "Verify the workflow URL matches the expected components."
  def verify_url(
        page,
        %{project_id: project_id, workflow_id: workflow_id, path: path} = options
      ) do
    url = "/projects/#{project_id}/w/#{workflow_id}#{path}"

    url =
      case options[:query] do
        nil -> url
        query -> url <> "?" <> URI.encode_query(query)
      end

    url = if hash = options[:hash], do: url <> "#" <> hash, else: url

    Expect.to_have_url!(page, url)
  end
end
