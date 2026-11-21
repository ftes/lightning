defmodule LightningE2E.Collaborative.RunRetryKeyboardShortcutsSpec do
  @moduledoc """
  E2E Test Suite: Run/Retry Keyboard Shortcuts.

  Cmd+Enter (Mac) / Ctrl+Enter (Windows/Linux): Run or Retry.
  Cmd+Shift+Enter / Ctrl+Shift+Enter: Force New Work Order.
  """
  use LightningE2E.Case, async: false

  # Run/Retry Keyboard Shortcuts @collaborative @critical
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

    # Wait for workflow canvas to be interactive (job nodes visible). We don't
    # strictly need full "Synced" state for keyboard shortcut tests
    page
    |> Page.locator(~s|[data-testid="job-node"]|)
    |> Locator.first()
    |> Locator.wait_for!(timeout: 30_000)

    %{test_data: test_data}
  end

  # `browserName === 'webkit' ? 'Meta' : 'Control'`: this project is chromium.
  @modifier_key "Control"

  defp press(page, key),
    do: page |> Page.keyboard() |> Playwright.Keyboard.press!(key)

  defp locator(page, selector), do: Page.locator(page, selector)

  defp first_job(page),
    do: page |> locator(~s|[data-testid="job-node"]|) |> Locator.first()

  defp open_manual_run_panel(page) do
    first_job(page) |> Locator.click!()

    # Click "Run" button to open Manual Run Panel
    page
    |> locator(~s|button:has-text("Run")|)
    |> Locator.first()
    |> Locator.click!()
  end

  defp run_workflow_now(page) do
    page |> locator(~s|button:has-text("Run Workflow Now")|) |> Locator.click!()
  end

  defp expect_run_started(page, text \\ "Run started") do
    page |> locator(~s|text="#{text}"|) |> Expect.to_be_visible!(timeout: 5000)
  end

  defp expect_retry_button(page, timeout) do
    page
    |> locator(~s|button:has-text("Retry")|)
    |> Expect.to_be_visible!(timeout: timeout)
  end

  test "Cmd+Enter triggers run from Manual Run Panel", %{page: page} do
    Test.step "Open Manual Run Panel" do
      # Click on a job to open inspector, then "Run" button to open Manual Run Panel
      open_manual_run_panel(page)

      # Verify panel is open
      page
      |> locator(~s|text="Run from"|)
      |> Locator.first()
      |> Expect.to_be_visible!()
    end

    Test.step "Press Cmd+Enter to trigger run" do
      # Press keyboard shortcut
      press(page, "#{@modifier_key}+Enter")

      # Verify run was triggered - look for success notification
      expect_run_started(page)

      page
      |> locator(~s|text="Saved latest changes and created new work order"|)
      |> Expect.to_be_visible!()
    end
  end

  test "Cmd+Enter triggers retry when following a run", %{page: page} do
    Test.step "Create a run first" do
      open_manual_run_panel(page)
      run_workflow_now(page)

      # Wait for run to start
      expect_run_started(page)
    end

    Test.step "Verify button shows retry mode" do
      expect_retry_button(page, 10_000)
    end

    Test.step "Press Cmd+Enter to trigger retry" do
      press(page, "#{@modifier_key}+Enter")

      # Verify retry was triggered
      expect_run_started(page, "Retry started")

      page
      |> locator(
        ~s|text="Saved latest changes and re-running with previous input"|
      )
      |> Expect.to_be_visible!()
    end
  end

  test "Cmd+Shift+Enter forces new work order", %{page: page} do
    Test.step "Create a run to enable retry mode" do
      open_manual_run_panel(page)
      run_workflow_now(page)
      expect_run_started(page)

      # Wait for retry mode
      expect_retry_button(page, 10_000)
    end

    Test.step "Press Cmd+Shift+Enter to force new work order" do
      # Press keyboard shortcut with Shift
      press(page, "#{@modifier_key}+Shift+Enter")

      # Verify NEW run was started (not retry)
      expect_run_started(page)

      # Should see "new work order" message, not "retry" message
      page
      |> locator(~s|text="Saved latest changes and created new work order"|)
      |> Expect.to_be_visible!()
    end
  end

  test "Keyboard shortcuts work in Monaco editor (IDE)", %{page: page} do
    Test.step "Open fullscreen IDE" do
      # Click on a job
      first_job(page) |> Locator.click!()

      # Click expand button to open fullscreen IDE
      page
      |> locator(~s|[aria-label="Open fullscreen editor"]|)
      |> Locator.click!()

      # Verify IDE is open
      page
      |> locator(~s|[data-testid="monaco-editor"]|)
      |> Expect.to_be_visible!(timeout: 5000)
    end

    Test.step "Focus Monaco editor and press Cmd+Enter" do
      # Click into Monaco editor to focus it
      page |> locator(~s|[data-testid="monaco-editor"]|) |> Locator.click!()

      # Press keyboard shortcut while focused in editor
      press(page, "#{@modifier_key}+Enter")

      # Verify run was triggered
      expect_run_started(page)
    end
  end

  test "Keyboard shortcuts respect disabled state", %{page: page} do
    Test.step "Open Manual Run Panel" do
      open_manual_run_panel(page)
    end

    Test.step "Try to run without selecting input" do
      # Switch to "existing" tab without selecting a dataclip
      page |> locator(~s|button:has-text("Existing")|) |> Locator.click!()

      # Press keyboard shortcut
      press(page, "#{@modifier_key}+Enter")

      # Verify NO run notification appears (should be disabled)
      page
      |> locator(~s|text="Run started"|)
      |> Expect.not_to_be_visible!(timeout: 2000)
    end
  end

  test "Split button dropdown works with mouse clicks", %{page: page} do
    Test.step "Create a run to enable split button" do
      open_manual_run_panel(page)
      run_workflow_now(page)
      expect_run_started(page)

      # Wait for split button to appear
      expect_retry_button(page, 10_000)
    end

    Test.step "Click main button to retry" do
      page |> locator(~s|button:has-text("Retry")|) |> Locator.click!()

      expect_run_started(page, "Retry started")
    end
  end

  test "Split button dropdown shows 'New Work Order' option", %{page: page} do
    Test.step "Create a run to enable split button" do
      open_manual_run_panel(page)
      run_workflow_now(page)
      expect_run_started(page)
      expect_retry_button(page, 10_000)
    end

    Test.step "Open dropdown and click 'New Work Order'" do
      # Click chevron to open dropdown
      page |> locator(~s|[aria-label="Open run options"]|) |> Locator.click!()

      # Verify dropdown is open
      page |> locator(~s|text="Run (New Work Order)"|) |> Expect.to_be_visible!()

      # Click the dropdown option
      page |> locator(~s|text="Run (New Work Order)"|) |> Locator.click!()

      # Verify new run (not retry)
      expect_run_started(page)

      page
      |> locator(~s|text="Saved latest changes and created new work order"|)
      |> Expect.to_be_visible!()
    end
  end

  test "Run state updates in real-time via WebSocket", %{page: page} do
    Test.step "Create a run" do
      open_manual_run_panel(page)
      run_workflow_now(page)
      expect_run_started(page)
    end

    Test.step "Verify button changes to Processing state" do
      # Button should show processing state
      page
      |> locator(~s|button:has-text("Processing")|)
      |> Expect.to_be_visible!(timeout: 5000)
    end

    Test.step "Verify button changes to Retry when complete" do
      # Wait for run to complete and button to change to retry
      expect_retry_button(page, 30_000)
    end
  end

  test "Cross-platform modifier keys work correctly", %{page: page} do
    Test.step "Verify correct modifier key for platform" do
      open_manual_run_panel(page)

      # Windows/Linux: Use Control (Mac: Meta, for webkit)
      press(page, "Control+Enter")

      # Both should trigger run
      expect_run_started(page)
    end
  end
end
