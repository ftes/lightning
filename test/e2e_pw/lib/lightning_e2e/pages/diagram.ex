defmodule LightningE2E.Pages.Diagram do
  @moduledoc """
  Port of `pages/components/workflow-diagram{,-nodes,-edges}.page.ts`: the React
  Flow canvas, its nodes and edges.
  """
  import ExUnit.Assertions, only: [assert: 1]
  alias Playwright.{Expect, Keyboard, Locator, Mouse, Page}

  @react_flow ".react-flow"
  @viewport ".react-flow__viewport"
  @fit_view_button ~s|.react-flow__controls-button[data-tooltip="Fit view"]|

  @edges ".react-flow__edge"
  @nodes ".react-flow__node"
  @job_nodes ".react-flow__node-job"
  @placeholder_node ".react-flow__node-placeholder"
  # The plus button IS a ReactFlow handle
  @node_connector ~s|[data-handleid="node-connector"]|

  ## WorkflowDiagramPage

  def verify_react_flow_present(page) do
    page |> Page.locator(@react_flow) |> Expect.to_be_visible!()
    page |> Page.locator(@viewport) |> Expect.to_be_visible!()
  end

  def click_fit_view(page) do
    fit_view_button = Page.locator(page, @fit_view_button)
    Expect.to_be_visible!(fit_view_button)
    Locator.click!(fit_view_button)
  end

  ## WorkflowDiagramNodesPage

  @doc "Find a React Flow node container by its display name/text."
  def node_by_name(page, name) do
    page |> Page.locator(@nodes) |> Locator.filter(has_text: name)
  end

  def job_by_index(page, index),
    do: page |> Page.locator(@job_nodes) |> Locator.nth(index)

  def all_nodes(page), do: Page.locator(page, @nodes)

  def placeholder(page), do: Page.locator(page, @placeholder_node)

  def verify_exists(page, name),
    do: page |> node_by_name(name) |> Expect.to_be_visible!()

  def verify_count(page, count),
    do: page |> all_nodes() |> Expect.to_have_count!(count)

  @doc "Verify a node shows valid drop state during drag."
  def verify_has_valid_drop_state(page, name) do
    is_valid =
      page
      |> node_by_name(name)
      |> Locator.evaluate!("""
      el => {
        return (
          el.getAttribute('data-valid-drop-target') === 'true' ||
          el.querySelector('[data-valid-drop-target="true"]') !== null
        );
      }
      """)

    assert(is_valid == true)
  end

  @doc "Verify a node shows invalid drop state during drag."
  def verify_has_invalid_drop_state(page, name) do
    is_invalid =
      page
      |> node_by_name(name)
      |> Locator.evaluate!("""
      el => {
        return (
          el.getAttribute('data-valid-drop-target') === 'false' ||
          el.querySelector('[data-valid-drop-target="false"]') !== null
        );
      }
      """)

    assert(is_invalid == true)
  end

  @doc "Verify a node displays a specific error message."
  def verify_shows_error(page, name, error_message) do
    page
    |> node_by_name(name)
    |> Locator.locator(~s|text="#{error_message}"|)
    |> Expect.to_be_visible!()
  end

  def click_node(page, name) do
    node = node_by_name(page, name)
    Expect.to_be_visible!(node)
    Locator.click!(node)
  end

  def click_job_by_index(page, index) do
    job_node = job_by_index(page, index)
    Expect.to_be_visible!(job_node)
    Locator.click!(job_node)
  end

  @doc "Click the plus button on a node to add a new connection."
  def click_plus_button_on(page, name) do
    node = node_by_name(page, name)
    Locator.hover!(node)

    plus_button = Locator.locator(node, @node_connector)
    Expect.to_be_visible!(plus_button)
    Locator.click!(plus_button)
  end

  @doc "Fill in the name of the placeholder node and confirm."
  def fill_placeholder_name(page, name) do
    placeholder = placeholder(page)
    Expect.to_be_visible!(placeholder)

    textbox =
      Locator.locator(
        placeholder,
        ~s|input[type="text"], input:not([type]), [role="textbox"]|
      )

    Expect.to_be_visible!(textbox)

    Locator.click!(textbox)
    Locator.fill!(textbox, name)
    Locator.press!(textbox, "Enter")
  end

  ## WorkflowDiagramEdgesPage

  def edge_count(page), do: page |> Page.locator(@edges) |> Locator.count!()

  @doc """
  Drag an edge from source to target node, using ReactFlow handles (hidden until
  the node is hovered: opacity-0 group-hover:opacity-100).
  """
  def drag_from_to(page, source_name, target_name) do
    source_node = node_by_name(page, source_name)
    target_node = node_by_name(page, target_name)

    # Hover source node to make handle visible
    Locator.hover!(source_node)
    Page.wait_for_timeout!(page, 200)

    source_handle = Locator.locator(source_node, @node_connector)
    Expect.to_be_visible!(source_handle)

    handle_box =
      Locator.bounding_box!(source_handle) ||
        raise "Could not get source handle bounding box"

    handle_x = handle_box["x"] + handle_box["width"] / 2
    handle_y = handle_box["y"] + handle_box["height"] / 2

    mouse = Page.mouse(page)

    # XYFlow pattern: hover handle -> mouse down
    Mouse.move!(mouse, handle_x, handle_y)
    Page.wait_for_timeout!(page, 100)
    Mouse.down!(mouse)
    Page.wait_for_timeout!(page, 100)

    target_box =
      Locator.bounding_box!(target_node) ||
        raise "Could not get target node bounding box"

    target_x = target_box["x"] + target_box["width"] / 2
    target_y = target_box["y"] + target_box["height"] / 2

    # Move to target with steps (important for ReactFlow to track drag)
    Mouse.move!(mouse, target_x, target_y, steps: 5)
    Page.wait_for_timeout!(page, 200)

    # Mouse up on target
    Mouse.up!(mouse)
    Page.wait_for_timeout!(page, 200)
  end

  @doc """
  Start dragging an edge from a node: hover the node and click the plus button
  (node connector). Does NOT trigger the visual feedback (onConnectStart): use
  `begin_drag/2` for that.
  """
  def start_dragging_from(page, source_name) do
    node = node_by_name(page, source_name)
    Locator.hover!(node)

    plus_button = Locator.locator(node, @node_connector)
    Expect.to_be_visible!(plus_button)
    Locator.click!(plus_button)
  end

  @doc """
  Begin an edge drag operation that triggers visual feedback. The mouse button is
  left down: call `release_drag/1` to cancel.
  """
  def begin_drag(page, source_name) do
    node = node_by_name(page, source_name)
    Locator.hover!(node)

    plus_button = Locator.locator(node, @node_connector)
    Expect.to_be_visible!(plus_button)

    bbox =
      Locator.bounding_box!(plus_button) ||
        raise "Could not get plus button bounding box"

    center_x = bbox["x"] + bbox["width"] / 2
    center_y = bbox["y"] + bbox["height"] / 2

    mouse = Page.mouse(page)
    Mouse.move!(mouse, center_x, center_y)
    Mouse.down!(mouse)

    # Move at least 2 pixels to exceed nodeDragThreshold: 1
    Mouse.move!(mouse, center_x + 2, center_y + 2)
    Page.wait_for_timeout!(page, 50)

    # Move the mouse significantly to trigger the drag state and onConnectStart
    Mouse.move!(mouse, center_x + 100, center_y + 100, steps: 10)

    # Wait for React Flow to process the drag start and update DOM
    Page.wait_for_timeout!(page, 200)
  end

  @doc "Release the mouse button, then press Escape to cancel the pending connection."
  def release_drag(page) do
    page |> Page.mouse() |> Mouse.up!()
    page |> Page.keyboard() |> Keyboard.press!("Escape")
  end
end
