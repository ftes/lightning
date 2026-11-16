defmodule LightningE2E.Collaborative.JobStepSyncSpec do
  @moduledoc """
  E2E Test Suite: Job-Step Selection Sync.

  When viewing a run in the collaborative editor IDE, clicking on different jobs
  correctly syncs the step selection URL parameter.
  See https://github.com/OpenFn/lightning/issues/4189
  """
  use LightningE2E.Case, async: false

  # Job-Step Selection Sync @collaborative
  setup %{page: page} do
    test_data = LightningE2E.test_data()

    # Enable experimental features to access collaborative editor
    LightningE2E.enable_experimental_features(test_data.users.editor.email)

    # Login as editor user
    Page.goto!(page, "/")

    Login.login_if_needed(
      page,
      test_data.users.editor.email,
      test_data.users.editor.password
    )

    # Navigate directly to the collaborative editor (the only editor)
    WorkflowCollab.open(page, %{
      project_id: test_data.projects.openhie.id,
      workflow_id: test_data.workflows.openhie.id
    })

    # Wait for workflow canvas to be interactive (job nodes visible)
    page
    |> Page.locator(~s|[data-testid="job-node"]|)
    |> Locator.first()
    |> Locator.wait_for!(timeout: 30_000)

    %{test_data: test_data}
  end

  defp step_param(page) do
    page
    |> Page.url()
    |> URI.parse()
    |> Map.get(:query, nil)
    |> then(&URI.decode_query(&1 || ""))
    |> Map.get("step")
  end

  defp job_selector(page) do
    # The JobSelector shows the current job name with a chevron
    Page.locator(page, "button")
    |> Locator.filter(has: Page.locator(page, ".hero-chevron-up-down"))
  end

  defp select_job(page, text) do
    # Click it to open the dropdown
    page |> job_selector() |> Locator.click!()

    # Wait for dropdown options to appear
    page |> Page.locator(~s|[role="listbox"]|) |> Expect.to_be_visible!()

    page
    |> Page.locator(~s|[role="option"]|)
    |> Locator.filter(has_text: text)
    |> Locator.click!()
  end

  test "clicking a job while viewing a run syncs step selection", %{page: page} do
    Test.step "Create a run via Manual Run Panel" do
      # Click on the first job to select it
      page
      |> Page.locator(~s|[data-testid="job-node"]|)
      |> Locator.first()
      |> Locator.click!()

      # Click "Run" button to open Manual Run Panel
      page
      |> Page.locator(~s|button:has-text("Run")|)
      |> Locator.first()
      |> Locator.click!()

      # Verify panel is open
      page
      |> Page.locator(~s|text="Run from"|)
      |> Locator.first()
      |> Expect.to_be_visible!()

      # Click "Run Workflow Now" button
      page
      |> Page.locator(~s|button:has-text("Run Workflow Now")|)
      |> Locator.click!()

      # Wait for run to start
      page
      |> Page.locator(~s|text="Run started"|)
      |> Expect.to_be_visible!(timeout: 5000)
    end

    Test.step "Wait for run to complete" do
      # Wait for retry button to appear (indicates run completed)
      page
      |> Page.locator(~s|button:has-text("Retry")|)
      |> Expect.to_be_visible!(timeout: 30_000)
    end

    Test.step "Open fullscreen IDE" do
      # Click expand button to open fullscreen IDE
      page
      |> Page.locator(~s|[aria-label="Open fullscreen editor"]|)
      |> Locator.click!()

      # Verify IDE is open
      page
      |> Page.locator(~s|[data-testid="monaco-editor"]|)
      |> Expect.to_be_visible!(timeout: 5000)
    end

    initial_step_param =
      Test.step "Record initial step param" do
        # The initial step param might be set or null depending on current selection
        step_param(page)
      end

    Test.step "Switch to a different job via JobSelector" do
      # Click on "Send to OpenHIM to route to SHR" (a different job)
      select_job(page, "Send to OpenHIM to route to SHR")
    end

    Test.step "Verify step param updated in URL" do
      # Wait a moment for the URL to update
      Page.wait_for_timeout!(page, 500)

      # The step param should be set (not null) since this job was executed
      new_step_param = step_param(page)
      refute is_nil(new_step_param)

      # If we had an initial step param, verify it's different
      if initial_step_param do
        refute new_step_param == initial_step_param
      end
    end

    Test.step "Switch to another job and verify step syncs again" do
      # Click on "Notify CHW upload successful"
      select_job(page, "Notify CHW upload successful")

      # Wait for URL to update
      Page.wait_for_timeout!(page, 500)

      # Verify step param is set for this job too
      refute is_nil(step_param(page))
    end
  end

  test "switching jobs updates step panel content", %{page: page} do
    Test.step "Create and wait for run to complete" do
      page
      |> Page.locator(~s|[data-testid="job-node"]|)
      |> Locator.first()
      |> Locator.click!()

      page
      |> Page.locator(~s|button:has-text("Run")|)
      |> Locator.first()
      |> Locator.click!()

      page
      |> Page.locator(~s|button:has-text("Run Workflow Now")|)
      |> Locator.click!()

      page
      |> Page.locator(~s|text="Run started"|)
      |> Expect.to_be_visible!(timeout: 5000)

      # Wait for run to complete
      page
      |> Page.locator(~s|button:has-text("Retry")|)
      |> Expect.to_be_visible!(timeout: 30_000)
    end

    Test.step "Open fullscreen IDE" do
      page
      |> Page.locator(~s|[aria-label="Open fullscreen editor"]|)
      |> Locator.click!()

      page
      |> Page.locator(~s|[data-testid="monaco-editor"]|)
      |> Expect.to_be_visible!(timeout: 5000)
    end

    Test.step "Verify run panel shows step information" do
      # The right panel should show run/step information
      page
      |> Page.locator("text=/Input|Output|Log/i")
      |> Locator.first()
      |> Expect.to_be_visible!(timeout: 5000)
    end

    Test.step "Switch job and verify panel updates" do
      # Switch to a different job
      select_job(page, "Send to OpenHIM to route to SHR")

      # Wait for panel to update
      Page.wait_for_timeout!(page, 500)

      # The panel should still show step information (for the new step)
      page
      |> Page.locator("text=/Input|Output|Log/i")
      |> Locator.first()
      |> Expect.to_be_visible!()
    end
  end
end
