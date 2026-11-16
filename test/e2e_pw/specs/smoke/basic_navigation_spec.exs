defmodule LightningE2E.Smoke.BasicNavigationSpec do
  use LightningE2E.Case, async: false

  test "homepage loads successfully", %{page: page} do
    Page.goto!(page, "/")

    # Wait for the page to load
    Page.wait_for_load_state!(page, :networkidle)

    # Check that we can see some basic Lightning content
    Expect.to_have_title!(page, ~r/Lightning/)
  end

  describe "Workflow Navigation with Dynamic Data" do
    setup %{page: page} do
      # Load test data once per test suite
      test_data = LightningE2E.test_data()

      # Login as editor user for most tests
      Page.goto!(page, "/")

      Login.login_if_needed(
        page,
        test_data.users.editor.email,
        test_data.users.editor.password
      )

      %{test_data: test_data}
    end

    test "can navigate to existing workflow and see React Flow with 5 nodes", %{
      page: page,
      test_data: test_data
    } do
      # Navigate to project using Projects page
      Projects.navigate_to_project(page, test_data.projects.openhie.name)
      LiveView.wait_for_connected(page)

      page |> Page.get_by_text("OpenHIE Workflow") |> Expect.to_be_visible!()

      # Navigate to the workflow. The workflow route renders the collaborative
      # editor directly (the only editor).
      Workflows.navigate_to_workflow(page, test_data.workflows.openhie.name)

      # Verify URL contains the actual workflow ID from database
      Expect.to_have_url!(page, ~r"/w/#{test_data.workflows.openhie.id}")

      # Wait for the collaborative editor to load and sync
      WorkflowCollab.wait_for_react_component_loaded(page)
      WorkflowCollab.wait_for_synced(page)

      Diagram.verify_react_flow_present(page)

      # Assert we have 5 nodes visible in the workflow (4 jobs + 1 trigger)
      Diagram.verify_count(page, 5)

      # Assert no error states are shown
      WorkflowCollab.verify_no_errors(page)

      page
      |> Page.locator("text=Something went wrong")
      |> Expect.not_to_be_visible!()

      page
      |> Page.locator("text=Invariant failed")
      |> Expect.not_to_be_visible!()
    end

    test "workflow data matches database state", %{
      page: page,
      test_data: test_data
    } do
      Projects.navigate_to_projects(page)

      # Verify the openhie project is visible
      Projects.verify_project_visible(page, test_data.projects.openhie.name)

      # Verify that editor user sees at least one project
      Projects.verify_projects_list_not_empty(page)
    end
  end
end
