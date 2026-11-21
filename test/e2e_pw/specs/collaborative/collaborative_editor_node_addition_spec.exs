defmodule LightningE2E.Collaborative.CollaborativeEditorNodeAdditionSpec do
  # The JS spec imports `authenticateViaUI` from `../../utils/auth`, a file that
  # does not exist, so Playwright can't load it (and with it, `playwright test`
  # aborts for the whole suite). The port uses the Login page for the same step,
  # and is skipped, as the JS spec effectively is: it also navigates to
  # `/projects/1/workflows`, which is not a project id.
  use LightningE2E.Case, async: false

  @moduletag skip:
               "JS spec cannot load: ../../utils/auth is missing; /projects/1 does not exist"

  # Collaborative Editor - Node Addition
  setup %{page: page} do
    test_data = LightningE2E.test_data()
    Page.goto!(page, "/")

    Login.login_if_needed(
      page,
      test_data.users.editor.email,
      test_data.users.editor.password
    )

    :ok
  end

  defp open_first_workflow(page) do
    # Navigate to a workflow with at least one existing node
    Page.goto!(page, "/projects/1/workflows")

    # Click the first workflow in the list
    page
    |> Page.locator(~s|[data-entity="workflow"]|)
    |> Locator.first()
    |> Locator.click!()
  end

  defp canvas(page), do: Page.locator(page, ".react-flow__renderer")

  defp first_node(page),
    do: page |> Page.locator(".react-flow__node") |> Locator.first()

  defp node_with(page, text),
    do:
      page |> Page.locator(".react-flow__node") |> Locator.filter(has_text: text)

  defp connector(node),
    do: Locator.locator(node, ~s|[data-handleid="node-connector"]|)

  defp placeholder_input(page), do: Page.locator(page, "input[data-placeholder]")

  defp add_node(page, node, name) do
    node |> connector() |> Locator.click!()
    input = placeholder_input(page)
    Locator.fill!(input, name)
    Locator.press!(input, "Enter")
  end

  defp drag_connector_to_empty_space(page) do
    box = page |> first_node() |> connector() |> Locator.bounding_box!()
    box || raise "Connector not found"
    mouse = Page.mouse(page)

    Playwright.Mouse.move!(
      mouse,
      box["x"] + box["width"] / 2,
      box["y"] + box["height"] / 2
    )

    Playwright.Mouse.down!(mouse)
    Playwright.Mouse.move!(mouse, box["x"] + 300, box["y"] + 200)
    Playwright.Mouse.up!(mouse)
  end

  defp adaptor_modal(page) do
    page
    |> Page.locator(~s|[role="dialog"]|)
    |> Locator.filter(has_text: "Select an adaptor")
  end

  test "canvas should remain visible after adding node with ENTER key", %{
    page: page
  } do
    open_first_workflow(page)

    # Wait for canvas to be visible
    Expect.to_be_visible!(canvas(page), timeout: 10_000)

    first_node = first_node(page)
    Expect.to_be_visible!(first_node)

    # Find existing job node and click its connector
    first_node |> connector() |> Locator.click!()

    # Placeholder should appear
    placeholder_input = placeholder_input(page)
    Expect.to_be_visible!(placeholder_input)

    # Type node name and press ENTER
    Locator.fill!(placeholder_input, "New Test Node")
    Locator.press!(placeholder_input, "Enter")

    # Canvas should still be visible
    Expect.to_be_visible!(canvas(page))

    # New node should appear immediately (within 2 seconds)
    Expect.to_be_visible!(node_with(page, "New Test Node"), timeout: 2000)

    # Placeholder should be gone
    Expect.not_to_be_visible!(placeholder_input)
  end

  test "should add multiple nodes sequentially without refresh", %{page: page} do
    open_first_workflow(page)
    Expect.to_be_visible!(canvas(page), timeout: 10_000)

    # Add first node
    add_node(page, first_node(page), "Sequential Node 1")

    # Verify first node added
    Expect.to_be_visible!(node_with(page, "Sequential Node 1"))

    # Add second node without refresh
    add_node(page, node_with(page, "Sequential Node 1"), "Sequential Node 2")

    # Both nodes should be visible
    Expect.to_be_visible!(node_with(page, "Sequential Node 1"))
    Expect.to_be_visible!(node_with(page, "Sequential Node 2"))

    # Canvas should still be visible
    Expect.to_be_visible!(canvas(page))
  end

  test "should persist node after hard refresh", %{page: page} do
    open_first_workflow(page)
    Expect.to_be_visible!(canvas(page), timeout: 10_000)

    # Add node
    add_node(page, first_node(page), "Persisted Node")

    # Verify node appears
    Expect.to_be_visible!(node_with(page, "Persisted Node"))

    # Hard refresh
    Page.reload!(page)

    # Node should still exist after refresh
    Expect.to_be_visible!(canvas(page), timeout: 10_000)
    Expect.to_be_visible!(node_with(page, "Persisted Node"))
  end

  test "should handle rapid node addition without canvas blank", %{page: page} do
    open_first_workflow(page)
    Expect.to_be_visible!(canvas(page), timeout: 10_000)

    # Add 5 nodes rapidly
    for i <- 1..5 do
      # Click connector on most recent node (or first node if i === 1)
      target_node =
        if i == 1,
          do: first_node(page),
          else: node_with(page, "Rapid Node #{i - 1}")

      add_node(page, target_node, "Rapid Node #{i}")

      # Canvas should remain visible throughout
      Expect.to_be_visible!(canvas(page))

      # Wait for node to appear before adding next
      Expect.to_be_visible!(node_with(page, "Rapid Node #{i}"), timeout: 2000)
    end

    # Verify all nodes are visible
    for i <- 1..5, do: Expect.to_be_visible!(node_with(page, "Rapid Node #{i}"))
  end

  test "should work in both auto and manual layout modes", %{page: page} do
    open_first_workflow(page)
    Expect.to_be_visible!(canvas(page), timeout: 10_000)

    # Test in auto layout mode (default)
    add_node(page, first_node(page), "Auto Layout Node")
    Expect.to_be_visible!(node_with(page, "Auto Layout Node"))

    # Switch to manual layout mode
    page
    |> Page.locator(
      ~s|.react-flow__controls button[data-tooltip*="manual layout"]|
    )
    |> Locator.click!()

    # Add node in manual layout mode
    add_node(page, node_with(page, "Auto Layout Node"), "Manual Layout Node")

    # Node should appear in manual layout mode
    Expect.to_be_visible!(node_with(page, "Manual Layout Node"))

    # Canvas should be visible
    Expect.to_be_visible!(canvas(page))
  end

  test "should open adaptor selection modal when dragging to empty space", %{
    page: page
  } do
    open_first_workflow(page)
    Expect.to_be_visible!(canvas(page), timeout: 10_000)

    drag_connector_to_empty_space(page)

    # Adaptor modal should appear
    modal = adaptor_modal(page)
    Expect.to_be_visible!(modal, timeout: 5000)

    # Search input should be visible
    modal
    |> Locator.locator(~s|input[placeholder="Search adaptors..."]|)
    |> Expect.to_be_visible!()
  end

  test "should create node with selected adaptor from modal", %{page: page} do
    open_first_workflow(page)
    Expect.to_be_visible!(canvas(page), timeout: 10_000)

    # Trigger modal by dragging to empty space
    drag_connector_to_empty_space(page)

    # Wait for modal
    modal = adaptor_modal(page)
    Expect.to_be_visible!(modal, timeout: 5000)

    # Search for http adaptor
    modal
    |> Locator.locator(~s|input[placeholder="Search adaptors..."]|)
    |> Locator.fill!("http")

    # Select http adaptor
    modal
    |> Locator.locator("button")
    |> Locator.filter(has_text: ~r/http/i)
    |> Locator.first()
    |> Locator.click!()

    # Modal should close
    Expect.not_to_be_visible!(modal)

    # New node with http adaptor should appear
    Expect.to_be_visible!(node_with(page, "http"), timeout: 5000)
  end

  test "should close adaptor modal when clicking outside", %{page: page} do
    open_first_workflow(page)
    Expect.to_be_visible!(canvas(page), timeout: 10_000)

    # Trigger modal
    drag_connector_to_empty_space(page)

    # Wait for modal
    modal = adaptor_modal(page)
    Expect.to_be_visible!(modal, timeout: 5000)

    # Close the modal
    page |> Page.keyboard() |> Playwright.Keyboard.press!("Escape")

    # Modal should close
    Expect.not_to_be_visible!(modal)

    # No new node should be created
    node_count = page |> Page.locator(".react-flow__node") |> Locator.count!()
    # Should have same number of nodes as before
    assert node_count >= 1
  end
end
