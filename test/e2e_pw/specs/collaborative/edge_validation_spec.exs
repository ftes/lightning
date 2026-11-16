defmodule LightningE2E.Collaborative.EdgeValidationSpec do
  @moduledoc """
  Edge Validation in Collaborative Editor.

  Tests the four edge validation rules: self-connection prevention, trigger
  connection prevention, circular workflow detection, duplicate edge prevention.
  """
  use LightningE2E.Case, async: false

  # Edge Validation in Collaborative Editor @collaborative
  setup %{page: page} do
    test_data = LightningE2E.test_data()

    # Enable experimental features
    LightningE2E.enable_experimental_features(test_data.users.editor.email)

    # Login
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

    # Wait for workflow diagram to be ready
    Diagram.verify_react_flow_present(page)

    %{test_data: test_data}
  end

  @transform "Transform data to FHIR standard"
  @send "Send to OpenHIM to route to SHR"
  @notify_ok "Notify CHW upload successful"
  @notify_failed "Notify CHW upload failed"

  defp trigger_node(page),
    do: page |> Page.locator(".react-flow__node-trigger") |> Locator.first()

  @tag skip:
         "ReactFlow's onConnect event doesn't fire reliably in Playwright (d3-drag timing)"
  test "should create valid edge between jobs", %{page: page} do
    Test.step "Verify initial workflow state" do
      # Workflow has 4 jobs and 1 trigger
      Diagram.verify_exists(page, @transform)
      Diagram.verify_exists(page, @send)
      Diagram.verify_exists(page, @notify_ok)
      Diagram.verify_exists(page, @notify_failed)
    end

    initial_edge_count =
      Test.step "Record initial edge count" do
        count = Diagram.edge_count(page)
        assert count == 4
        count
      end

    Test.step "Create edge from 'Notify CHW upload successful' to 'Notify CHW upload failed'" do
      Diagram.drag_from_to(page, @notify_ok, @notify_failed)

      # Wait for Y.js sync
      WorkflowCollab.wait_for_synced(page)

      # Small delay to ensure edge is rendered
      Page.wait_for_timeout!(page, 500)
    end

    Test.step "Verify edge was created" do
      assert Diagram.edge_count(page) == initial_edge_count + 1
    end

    Test.step "Verify edge persists after reload" do
      Page.reload!(page)

      WorkflowCollab.wait_for_react_component_loaded(page)
      WorkflowCollab.wait_for_synced(page)

      Diagram.verify_react_flow_present(page)

      assert Diagram.edge_count(page) == initial_edge_count + 1
    end
  end

  test "should prevent self-connection", %{page: page} do
    Test.step "Attempt to connect job to itself" do
      initial_edge_count = Diagram.edge_count(page)

      # Start dragging from a job
      Diagram.start_dragging_from(page, @transform)

      # Try to drop on the same job
      page |> Diagram.node_by_name(@transform) |> Locator.click!()

      # Release drag
      Diagram.release_drag(page)

      # Verify no new edge created
      assert Diagram.edge_count(page) == initial_edge_count
    end

    Test.step "Verify final edge count unchanged" do
      # Self-connection should not have been created (4 edges)
      assert Diagram.edge_count(page) == 4
    end
  end

  test "should prevent connection to trigger", %{page: page} do
    initial_edge_count =
      Test.step "Record initial state" do
        # Get initial edge count before any operations
        count = Diagram.edge_count(page)
        assert count == 4

        # Verify trigger node exists
        Expect.to_be_visible!(trigger_node(page))
        count
      end

    Test.step "Start dragging from job" do
      Diagram.start_dragging_from(page, @transform)
    end

    Test.step "Attempt to connect to trigger" do
      trigger_node = trigger_node(page)

      # Try to connect to it
      Locator.hover!(trigger_node)
      Locator.click!(trigger_node)

      # Small delay to let React Flow process the attempt
      Page.wait_for_timeout!(page, 200)
    end

    Test.step "Verify no edge was created" do
      # Ensure React Flow is still rendered
      Diagram.verify_react_flow_present(page)

      # The existing edges are FROM trigger TO job: verify no edge FROM job TO trigger
      assert Diagram.edge_count(page) == initial_edge_count
    end
  end

  test "should prevent two-node circular workflow", %{page: page} do
    initial_edge_count =
      Test.step "Record initial state" do
        # Edges: Trigger -> Transform -> Send -> Notify successful / failed
        count = Diagram.edge_count(page)
        assert count == 4
        count
      end

    Test.step "Start dragging from 'Send to OpenHIM to route to SHR'" do
      Diagram.start_dragging_from(page, @send)
    end

    Test.step "Attempt to connect back to 'Transform data to FHIR standard'" do
      # This would create a 2-node cycle
      page |> Diagram.node_by_name(@transform) |> Locator.click!()

      # Small delay to let React Flow process
      Page.wait_for_timeout!(page, 200)

      # Release the drag to clean up drag state
      Diagram.release_drag(page)
    end

    Test.step "Verify no circular edge was created" do
      assert Diagram.edge_count(page) == initial_edge_count
    end
  end

  test "should prevent three-node circular workflow", %{page: page} do
    initial_edge_count =
      Test.step "Record initial state" do
        count = Diagram.edge_count(page)
        assert count == 4
        count
      end

    Test.step "Start dragging from 'Notify CHW upload successful'" do
      Diagram.start_dragging_from(page, @notify_ok)
    end

    Test.step "Attempt to connect back to 'Transform data to FHIR standard'" do
      # This would create a 3-node cycle
      page |> Diagram.node_by_name(@transform) |> Locator.click!()

      # Small delay to let React Flow process
      Page.wait_for_timeout!(page, 200)

      # Release the drag to clean up drag state
      Diagram.release_drag(page)
    end

    Test.step "Verify no circular edge was created" do
      assert Diagram.edge_count(page) == initial_edge_count
    end
  end

  @tag skip:
         "ReactFlow's onConnect doesn't fire reliably in Playwright automation"
  test "should allow diamond pattern (not a cycle)", %{page: page} do
    initial_edge_count =
      Test.step "Record initial state" do
        count = Diagram.edge_count(page)
        assert count == 4
        count
      end

    Test.step "Create new edge completing a valid diamond" do
      # Connect Transform -> Notify failed: a valid DAG (diamond pattern, not a cycle)
      Diagram.drag_from_to(page, @transform, @notify_failed)

      WorkflowCollab.wait_for_synced(page)
      Page.wait_for_timeout!(page, 300)
    end

    Test.step "Verify diamond pattern is valid (no cycle)" do
      assert Diagram.edge_count(page) == initial_edge_count + 1
    end
  end

  test "should prevent duplicate edge", %{page: page} do
    initial_edge_count =
      Test.step "Record initial state" do
        # Existing edge: Transform -> Send
        count = Diagram.edge_count(page)
        assert count == 4
        count
      end

    Test.step "Start dragging from 'Transform data to FHIR standard'" do
      Diagram.start_dragging_from(page, @transform)
    end

    Test.step "Attempt to create duplicate edge to 'Send to OpenHIM to route to SHR'" do
      # This edge already exists, should be prevented
      page |> Diagram.node_by_name(@send) |> Locator.click!()

      # Small delay to let React Flow process
      Page.wait_for_timeout!(page, 200)

      # Release the drag to clean up drag state
      Diagram.release_drag(page)
    end

    Test.step "Verify no duplicate edge was created" do
      assert Diagram.edge_count(page) == initial_edge_count
    end
  end

  @tag skip:
         "ReactFlow's onConnect doesn't fire reliably in Playwright automation"
  test "should allow edge from different source to same target", %{page: page} do
    initial_edge_count =
      Test.step "Record initial state" do
        # "Send to OpenHIM" already has edge to "Notify CHW upload successful"
        count = Diagram.edge_count(page)
        assert count == 4
        count
      end

    Test.step "Create edge from different source to same target" do
      # Connect Transform -> Notify successful: allowed since different source
      Diagram.drag_from_to(page, @transform, @notify_ok)

      WorkflowCollab.wait_for_synced(page)
      Page.wait_for_timeout!(page, 300)
    end

    Test.step "Verify both edges to same target exist" do
      assert Diagram.edge_count(page) == initial_edge_count + 1
    end
  end

  ## Visual Feedback Tests

  @tag skip:
         "ReactFlow's onConnectStart doesn't fire reliably in Playwright (d3-drag timing)"
  test "should show visual feedback during edge drag", %{page: page} do
    drop_state_attr = fn node, attr, value ->
      Locator.evaluate!(node, "el => el.getAttribute('#{attr}') === '#{value}'")
    end

    Test.step "Begin edge drag from 'Transform data to FHIR standard'" do
      # Use begin_drag, which triggers onConnectStart and visual feedback
      Diagram.begin_drag(page, @transform)
      Page.wait_for_timeout!(page, 200)
    end

    Test.step "Verify valid targets show success state" do
      Diagram.verify_has_valid_drop_state(page, @notify_ok)
      Diagram.verify_has_valid_drop_state(page, @notify_failed)
    end

    Test.step "Verify invalid targets show error state" do
      # Transform itself (self-connection) should be invalid
      Diagram.verify_has_invalid_drop_state(page, @transform)

      # Trigger should be invalid
      has_invalid_state =
        Locator.evaluate!(trigger_node(page), """
        el => {
          return (
            el.getAttribute('data-valid-drop-target') === 'false' ||
            el.querySelector('[data-valid-drop-target="false"]') !== null
          );
        }
        """)

      assert has_invalid_state == true
    end

    Test.step "Hover over 'Notify CHW upload successful' and verify active state" do
      node = Diagram.node_by_name(page, @notify_ok)
      Locator.hover!(node)

      # Small delay for active state to update
      Page.wait_for_timeout!(page, 100)

      assert drop_state_attr.(node, "data-active-drop-target", "true") == true
    end

    Test.step "Move to 'Notify CHW upload failed' and verify state clears on first node" do
      node_success = Diagram.node_by_name(page, @notify_ok)
      node_failed = Diagram.node_by_name(page, @notify_failed)

      Locator.hover!(node_failed)
      Page.wait_for_timeout!(page, 100)

      assert drop_state_attr.(node_success, "data-active-drop-target", "true") ==
               false

      assert drop_state_attr.(node_failed, "data-active-drop-target", "true") ==
               true
    end

    Test.step "Release drag and verify all visual states clear" do
      Diagram.release_drag(page)

      # Wait for state to clear
      Page.wait_for_timeout!(page, 300)

      for node <- page |> Diagram.all_nodes() |> Locator.all!() do
        has_drop_target_state =
          Locator.evaluate!(
            node,
            "el => el.getAttribute('data-valid-drop-target') !== null"
          )

        # Drop target states should be cleared
        assert has_drop_target_state == false
      end

      for node <- page |> Diagram.all_nodes() |> Locator.all!() do
        assert drop_state_attr.(node, "data-active-drop-target", "true") == false
      end
    end
  end

  @tag skip: "ReactFlow's onConnectStart doesn't fire reliably in Playwright"
  test "should display error messages during drag", %{page: page} do
    Test.step "Begin edge drag from 'Transform data to FHIR standard'" do
      Diagram.begin_drag(page, @transform)
      Page.wait_for_timeout!(page, 200)
    end

    Test.step "Verify duplicate edge error on 'Send to OpenHIM to route to SHR'" do
      # Hover over the node to activate it and show the error
      page |> Diagram.node_by_name(@send) |> Locator.hover!()
      Page.wait_for_timeout!(page, 100)

      Diagram.verify_shows_error(page, @send, "Already connected to this step")
    end

    Test.step "Release drag and begin new drag from 'Send to OpenHIM to route to SHR'" do
      Diagram.release_drag(page)
      Page.wait_for_timeout!(page, 300)

      Diagram.begin_drag(page, @send)
      Page.wait_for_timeout!(page, 200)
    end

    Test.step "Verify circular workflow error on 'Transform data to FHIR standard'" do
      page |> Diagram.node_by_name(@transform) |> Locator.hover!()
      Page.wait_for_timeout!(page, 100)

      Diagram.verify_shows_error(
        page,
        @transform,
        "Cannot create circular workflow"
      )
    end

    Test.step "Release drag and begin new drag from 'Notify CHW upload successful'" do
      Diagram.release_drag(page)
      Page.wait_for_timeout!(page, 300)

      Diagram.begin_drag(page, @notify_ok)
      Page.wait_for_timeout!(page, 200)
    end

    Test.step "Verify trigger error message" do
      trigger_node = trigger_node(page)

      # Hover over trigger to activate it
      Locator.hover!(trigger_node)
      Page.wait_for_timeout!(page, 100)

      # The error message is rendered as a sibling to the node, so check the
      # text content in a broader scope
      error_visible =
        Locator.evaluate!(trigger_node, """
        el => {
          const parent = el.parentElement;
          if (parent) {
            const text = parent.textContent || '';
            return text.includes('Cannot connect to a trigger');
          }
          return false;
        }
        """)

      assert error_visible == true
    end

    Test.step "Release drag to clean up" do
      Diagram.release_drag(page)
      Page.wait_for_timeout!(page, 200)
    end
  end
end
