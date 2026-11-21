defmodule LightningE2E.Collaborative.JobInspectorConfigurationSpec do
  use LightningE2E.Case, async: false

  # Job Inspector Configuration Flow
  setup %{page: page} do
    test_data = LightningE2E.test_data()

    Page.goto!(page, "/")

    Login.login_if_needed(
      page,
      test_data.users.editor.email,
      test_data.users.editor.password
    )

    %{test_data: test_data}
  end

  @search_placeholder "Search for an adaptor to connect..."

  defp first_node(page),
    do: page |> Page.locator(".react-flow__node") |> Locator.first()

  defp node_connector(node),
    do: Locator.locator(node, ~s|[data-handleid="node-connector"]|)

  defp name_input(page),
    do: page |> Page.locator(~s|input[name="name"]|) |> Locator.first()

  defp open_first_workflow(page) do
    Page.goto!(page, "/projects/1/workflows")

    page
    |> Page.locator(~s|[data-entity="workflow"]|)
    |> Locator.first()
    |> Locator.click!()
  end

  # Drag from the first node's connector to empty space
  defp drag_to_empty_space(page) do
    connector_box =
      page |> first_node() |> node_connector() |> Locator.bounding_box!()

    connector_box || raise "Connector not found"

    mouse = Page.mouse(page)

    Playwright.Mouse.move!(
      mouse,
      connector_box["x"] + connector_box["width"] / 2,
      connector_box["y"] + connector_box["height"] / 2
    )

    Playwright.Mouse.down!(mouse)

    Playwright.Mouse.move!(
      mouse,
      connector_box["x"] + 300,
      connector_box["y"] + 200
    )

    Playwright.Mouse.up!(mouse)
  end

  test "complete job creation and configuration flow", %{page: page} do
    Test.step "Navigate to workflow" do
      open_first_workflow(page)

      # Wait for canvas to be visible
      page
      |> Page.locator(".react-flow__renderer")
      |> Expect.to_be_visible!(timeout: 10_000)
    end

    Test.step "Create new job via connector" do
      # Click connector to add new node
      first_node = first_node(page)
      Expect.to_be_visible!(first_node)

      first_node |> node_connector() |> Locator.click!()
    end

    Test.step "Select adaptor from modal" do
      # Wait for adaptor modal
      modal = Page.locator(page, ~s|[role="dialog"]|)
      Expect.to_be_visible!(modal, timeout: 5000)

      # Search for Salesforce adaptor
      search_input = Page.get_by_placeholder(page, @search_placeholder)
      Expect.to_be_visible!(search_input)
      Locator.fill!(search_input, "salesforce")

      # Select Salesforce adaptor
      modal
      |> Locator.locator("button")
      |> Locator.filter(has_text: ~r/salesforce/i)
      |> Locator.first()
      |> Locator.click!()
    end

    Test.step "Verify inspector auto-opens with job" do
      # Modal should close
      page
      |> Page.get_by_placeholder(@search_placeholder)
      |> Expect.not_to_be_visible!()

      # Inspector should be visible
      # (Inspector is part of main layout, check for job name field)
      name_input = name_input(page)
      Expect.to_be_visible!(name_input, timeout: 3000)

      # Job name should default to adaptor name
      Expect.to_have_value!(name_input, ~r/salesforce/i)
    end

    Test.step "Verify adaptor display section (Phase 2R)" do
      # Check for "Adaptor" label
      page |> Page.get_by_text("Adaptor", exact: true) |> Expect.to_be_visible!()

      # Check adaptor display shows Salesforce
      page |> Page.get_by_text("Salesforce") |> Expect.to_be_visible!()

      # Phase 2R: Check "Connect" button exists (changed from "Change")
      connect_button = Page.get_by_role(page, :button, name: ~r/configure/i)
      Expect.to_be_visible!(connect_button)
      Expect.to_have_text!(connect_button, "Connect")
    end

    Test.step "Configure adaptor via Connect button (Phase 3R)" do
      # Click "Connect" button to open ConfigureAdaptorModal
      page |> Page.get_by_role(:button, name: ~r/configure/i) |> Locator.click!()

      # ConfigureAdaptorModal should open
      page
      |> Page.get_by_text("Configure Your Adaptor")
      |> Expect.to_be_visible!()

      # Verify current adaptor is shown
      page |> Page.get_by_text("Salesforce") |> Expect.to_be_visible!()

      # Verify version dropdown is visible with current version
      version_dropdown =
        page
        |> Page.locator("select")
        |> Locator.filter(has: Page.locator(page, ~s|option[value="2.1.0"]|))

      Expect.to_be_visible!(version_dropdown)

      # Click "Change" button within modal to change adaptor
      page
      |> Page.locator(~s|[role="dialog"]|)
      |> Locator.get_by_role(:button, name: ~r/change/i)
      |> Locator.click!()

      # Nested AdaptorSelectionModal should open
      page
      |> Page.get_by_placeholder(@search_placeholder)
      |> Expect.to_be_visible!()

      # Search for HTTP adaptor
      search_input = Page.get_by_placeholder(page, @search_placeholder)
      Locator.clear!(search_input)
      Locator.fill!(search_input, "http")

      # Select HTTP adaptor
      page
      |> Page.locator("button")
      |> Locator.filter(has_text: ~r/^http$/i)
      |> Locator.first()
      |> Locator.click!()

      # Nested modal should close, back to ConfigureAdaptorModal
      page
      |> Page.get_by_placeholder(@search_placeholder)
      |> Expect.not_to_be_visible!()

      # ConfigureAdaptorModal should still be open with Http selected
      page
      |> Page.get_by_text("Configure Your Adaptor")
      |> Expect.to_be_visible!()

      page |> Page.get_by_text("Http") |> Expect.to_be_visible!(timeout: 3000)

      # Save changes
      page
      |> Page.locator(~s|[role="dialog"]|)
      |> Locator.get_by_role(:button, name: ~r/save/i)
      |> Locator.click!()

      # Modal should close
      page
      |> Page.get_by_text("Configure Your Adaptor")
      |> Expect.not_to_be_visible!()

      # Adaptor in inspector should update to Http
      page |> Page.get_by_text("Http") |> Expect.to_be_visible!(timeout: 3000)
    end

    Test.step "Edit job name" do
      name_input = name_input(page)
      Locator.fill!(name_input, "My HTTP Job")

      # Verify value updated
      Expect.to_have_value!(name_input, "My HTTP Job")
    end

    Test.step "Verify changes persist after navigation" do
      # Click on canvas to deselect (close inspector if needed)
      page
      |> Page.locator(".react-flow__renderer")
      |> Locator.click!(position: %{x: 50, y: 50})

      # Wait a moment for any saves to complete
      Page.wait_for_timeout!(page, 500)

      # Click on the newly created node to reopen inspector
      page
      |> Page.locator(".react-flow__node")
      |> Locator.filter(has_text: "My HTTP Job")
      |> Locator.click!()

      # Verify all changes persisted
      Expect.to_have_value!(name_input(page), "My HTTP Job")
      page |> Page.get_by_text("Http") |> Expect.to_be_visible!()
    end
  end

  test "inspector opens after drag-to-space node creation", %{page: page} do
    open_first_workflow(page)

    page
    |> Page.locator(".react-flow__renderer")
    |> Expect.to_be_visible!(timeout: 10_000)

    # Get first node connector, and drag to empty space
    drag_to_empty_space(page)

    # Adaptor modal should open
    page
    |> Page.locator(~s|[role="dialog"]|)
    |> Expect.to_be_visible!(timeout: 5000)

    # Select HTTP adaptor
    page |> Page.get_by_placeholder(@search_placeholder) |> Locator.fill!("http")

    page
    |> Page.locator("button")
    |> Locator.filter(has_text: ~r/^http$/i)
    |> Locator.first()
    |> Locator.click!()

    # Inspector should auto-open with new job
    name_input = name_input(page)
    Expect.to_be_visible!(name_input, timeout: 3000)
    Expect.to_have_value!(name_input, ~r/http/i)
  end

  test "multiple adaptors can be configured sequentially", %{page: page} do
    open_first_workflow(page)

    page
    |> Page.locator(".react-flow__renderer")
    |> Expect.to_be_visible!(timeout: 10_000)

    # Create first job
    Test.step "Create first job with Salesforce" do
      first_node(page) |> node_connector() |> Locator.click!()

      # Select Salesforce
      page
      |> Page.get_by_placeholder(@search_placeholder)
      |> Locator.fill!("salesforce")

      page
      |> Page.locator("button")
      |> Locator.filter(has_text: ~r/salesforce/i)
      |> Locator.first()
      |> Locator.click!()

      # Set name and verify
      name_input = name_input(page)
      Expect.to_be_visible!(name_input)
      Locator.fill!(name_input, "Job 1")
      page |> Page.get_by_text("Salesforce") |> Expect.to_be_visible!()
    end

    # Create second job
    Test.step "Create second job with HTTP" do
      # Click away to deselect first job
      page
      |> Page.locator(".react-flow__renderer")
      |> Locator.click!(position: %{x: 50, y: 50})

      # Find the newly created "Job 1" node and add another job
      job1_node =
        page
        |> Page.locator(".react-flow__node")
        |> Locator.filter(has_text: "Job 1")

      Expect.to_be_visible!(job1_node)

      job1_node |> node_connector() |> Locator.click!()

      # Select HTTP
      page
      |> Page.get_by_placeholder(@search_placeholder)
      |> Locator.fill!("http")

      page
      |> Page.locator("button")
      |> Locator.filter(has_text: ~r/^http$/i)
      |> Locator.first()
      |> Locator.click!()

      # Set name and verify
      name_input = name_input(page)
      Expect.to_be_visible!(name_input)
      Locator.fill!(name_input, "Job 2")
    end

    # Verify both jobs exist
    page
    |> Page.locator(".react-flow__node")
    |> Locator.filter(has_text: "Job 1")
    |> Expect.to_be_visible!()

    page
    |> Page.locator(".react-flow__node")
    |> Locator.filter(has_text: "Job 2")
    |> Expect.to_be_visible!()
  end
end
