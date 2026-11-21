defmodule LightningE2E.Collaborative.CollaborativeEditorCredentialsSpec do
  use LightningE2E.Case, async: false

  # Collaborative Editor - Job Credentials
  setup %{page: page} do
    test_data = LightningE2E.test_data()

    # Enable experimental features for the editor user
    LightningE2E.enable_experimental_features(test_data.users.editor.email)

    # Login as editor user
    Page.goto!(page, "/")

    Login.login_if_needed(
      page,
      test_data.users.editor.email,
      test_data.users.editor.password
    )

    %{test_data: test_data}
  end

  defp open_workflow(page, test_data) do
    Test.step "Open workflow in collaborative editor" do
      WorkflowCollab.open(page, %{
        project_id: test_data.projects.openhie.id,
        workflow_id: test_data.workflows.openhie.id
      })
    end
  end

  defp first_job(page),
    do: Page.locator(page, ".react-flow__node-job") |> Locator.first()

  defp job_at(page, index),
    do: Page.locator(page, ".react-flow__node-job") |> Locator.nth(index)

  defp session_storage_set(page, key, value) do
    Page.evaluate!(
      page,
      "id => window.sessionStorage.setItem('#{key}', id)",
      value
    )
  end

  defp session_storage_get(page, key) do
    Page.evaluate!(page, "() => window.sessionStorage.getItem('#{key}')")
  end

  test "Save job without credential in collaborative editor", %{
    page: page,
    test_data: test_data
  } do
    open_workflow(page, test_data)

    Test.step "Configure job WITHOUT selecting a credential" do
      # Click first job node
      page |> first_job() |> Locator.click!()

      # Wait for job inspector to be visible
      JobInspector.wait_for_visible(page)

      # Configure job name
      JobInspector.set_name(page, "Simple Transform")

      # Verify credential dropdown shows no selection (empty value)
      page |> JobInspector.credential_select() |> Expect.to_have_value!("")
    end

    Test.step "Save workflow" do
      WorkflowCollab.save_workflow(page)

      # Wait for save to complete (check for synced status)
      WorkflowCollab.wait_for_synced(page)
    end

    Test.step "Reload and verify job persisted without credential" do
      Page.reload!(page)

      WorkflowCollab.wait_for_react_component_loaded(page)
      WorkflowCollab.wait_for_synced(page)

      # Click job again
      page |> first_job() |> Locator.click!()
      JobInspector.wait_for_visible(page)

      # Verify credential is still empty
      page |> JobInspector.credential_select() |> Expect.to_have_value!("")

      page
      |> JobInspector.name_input()
      |> Expect.to_have_value!("Simple Transform")
    end
  end

  test "Save job with project credential", %{page: page, test_data: test_data} do
    open_workflow(page, test_data)

    Test.step "Select a project credential" do
      # Click first job node
      page |> first_job() |> Locator.click!()
      JobInspector.wait_for_visible(page)

      # Configure job
      JobInspector.set_name(page, "HTTP Request")

      # Select first available credential (skip placeholder at index 0)
      page
      |> JobInspector.credential_select()
      |> Locator.select_option!(%{index: 1})

      # Get the selected credential value for verification later
      selected_credential_id = JobInspector.get_selected_credential(page)
      refute selected_credential_id == ""

      # Store for next step
      session_storage_set(page, "selectedCredentialId", selected_credential_id)
    end

    Test.step "Save and verify" do
      WorkflowCollab.save_workflow(page)
      WorkflowCollab.wait_for_synced(page)
    end

    Test.step "Reload and verify persistence" do
      selected_credential_id = session_storage_get(page, "selectedCredentialId")

      Page.reload!(page)

      WorkflowCollab.wait_for_react_component_loaded(page)
      WorkflowCollab.wait_for_synced(page)

      page |> first_job() |> Locator.click!()
      JobInspector.wait_for_visible(page)

      page
      |> JobInspector.credential_select()
      |> Expect.to_have_value!(selected_credential_id)
    end
  end

  test "Clear credential after it was selected", %{
    page: page,
    test_data: test_data
  } do
    open_workflow(page, test_data)

    Test.step "First, select a credential" do
      page |> first_job() |> Locator.click!()
      JobInspector.wait_for_visible(page)

      page
      |> JobInspector.credential_select()
      |> Locator.select_option!(%{index: 1})

      page |> JobInspector.credential_select() |> Expect.not_to_have_value!("")
    end

    Test.step "Save with credential" do
      WorkflowCollab.save_workflow(page)
      WorkflowCollab.wait_for_synced(page)
    end

    Test.step "Clear the credential by selecting placeholder" do
      JobInspector.clear_credential(page)
      page |> JobInspector.credential_select() |> Expect.to_have_value!("")
    end

    Test.step "Save without credential" do
      WorkflowCollab.save_workflow(page)
      WorkflowCollab.wait_for_synced(page)
    end

    Test.step "Reload and verify credential is cleared" do
      Page.reload!(page)

      WorkflowCollab.wait_for_react_component_loaded(page)
      WorkflowCollab.wait_for_synced(page)

      page |> first_job() |> Locator.click!()
      JobInspector.wait_for_visible(page)

      page |> JobInspector.credential_select() |> Expect.to_have_value!("")
    end
  end

  test "Switch between project and keychain credentials", %{
    page: page,
    test_data: test_data
  } do
    open_workflow(page, test_data)

    keychain_option = fn ->
      page
      |> JobInspector.credential_select()
      |> Locator.locator(~s|optgroup[label*="Keychain"] option|)
      |> Locator.first()
    end

    # Check if keychain credentials exist
    has_keychain_creds =
      Test.step "Check if keychain credentials exist" do
        page |> first_job() |> Locator.click!()
        JobInspector.wait_for_visible(page)

        Locator.count!(keychain_option.()) > 0
      end

    # `test.skip()` at runtime: ExUnit can't skip a running test, so the rest is
    # guarded (reported as passed).
    if has_keychain_creds do
      Test.step "Select project credential" do
        page
        |> JobInspector.credential_select()
        |> Locator.select_option!(%{index: 1})

        project_cred_id = JobInspector.get_selected_credential(page)

        session_storage_set(page, "projectCredId", project_cred_id)

        WorkflowCollab.save_workflow(page)
        WorkflowCollab.wait_for_synced(page)
      end

      Test.step "Switch to keychain credential" do
        Locator.click!(keychain_option.())

        keychain_cred_id = JobInspector.get_selected_credential(page)
        project_cred_id = session_storage_get(page, "projectCredId")

        refute keychain_cred_id == project_cred_id

        session_storage_set(page, "keychainCredId", keychain_cred_id)

        WorkflowCollab.save_workflow(page)
        WorkflowCollab.wait_for_synced(page)
      end

      Test.step "Verify persistence" do
        keychain_cred_id = session_storage_get(page, "keychainCredId")

        Page.reload!(page)

        WorkflowCollab.wait_for_react_component_loaded(page)
        WorkflowCollab.wait_for_synced(page)

        page |> first_job() |> Locator.click!()
        JobInspector.wait_for_visible(page)

        page
        |> JobInspector.credential_select()
        |> Expect.to_have_value!(keychain_cred_id)
      end
    end
  end

  test "Multiple jobs with different credential configurations", %{
    page: page,
    test_data: test_data
  } do
    open_workflow(page, test_data)

    Test.step "Configure first job with no credential" do
      page |> first_job() |> Locator.click!()
      JobInspector.wait_for_visible(page)

      JobInspector.set_name(page, "Job 1 - No Cred")
      JobInspector.clear_credential(page)
    end

    Test.step "Add second job via plus button" do
      # Hover over first job to reveal plus button
      first_job_node = first_job(page)
      Locator.hover!(first_job_node)

      # Click the plus button (node connector)
      first_job_node
      |> Locator.locator(~s|[data-handleid="node-connector"]|)
      |> Locator.click!()

      # Wait for second job to be created
      Page.wait_for_timeout!(page, 500)
    end

    Test.step "Configure second job with credential" do
      # Click second job
      page |> job_at(1) |> Locator.click!()
      JobInspector.wait_for_visible(page)

      JobInspector.set_name(page, "Job 2 - With Cred")

      page
      |> JobInspector.credential_select()
      |> Locator.select_option!(%{index: 1})

      selected_cred_id = JobInspector.get_selected_credential(page)
      session_storage_set(page, "job2CredId", selected_cred_id)
    end

    Test.step "Save all changes" do
      WorkflowCollab.save_workflow(page)
      WorkflowCollab.wait_for_synced(page)
    end

    Test.step "Verify each job persisted correctly" do
      job2_cred_id = session_storage_get(page, "job2CredId")

      Page.reload!(page)

      WorkflowCollab.wait_for_react_component_loaded(page)
      WorkflowCollab.wait_for_synced(page)

      # Verify first job (no credential)
      page |> first_job() |> Locator.click!()
      JobInspector.wait_for_visible(page)

      page
      |> JobInspector.name_input()
      |> Expect.to_have_value!("Job 1 - No Cred")

      page |> JobInspector.credential_select() |> Expect.to_have_value!("")

      # Verify second job (with credential)
      second_job_node = job_at(page, 1)
      second_job_exists = Locator.count!(second_job_node) > 0

      if second_job_exists do
        Locator.click!(second_job_node)
        JobInspector.wait_for_visible(page)

        page
        |> JobInspector.name_input()
        |> Expect.to_have_value!("Job 2 - With Cred")

        page
        |> JobInspector.credential_select()
        |> Expect.to_have_value!(job2_cred_id)
      end
    end
  end

  test "Job created via diagram plus button has null credentials", %{
    page: page,
    test_data: test_data
  } do
    open_workflow(page, test_data)

    Test.step "Add new job via plus button" do
      # Hover over first job to reveal plus button
      first_job_node = first_job(page)
      Locator.hover!(first_job_node)

      # Click the plus button to add a new job
      first_job_node
      |> Locator.locator(~s|[data-handleid="node-connector"]|)
      |> Locator.click!()

      # Wait for new job to be created
      Page.wait_for_timeout!(page, 500)
    end

    Test.step "Verify the new job has credential dropdown available" do
      page |> job_at(1) |> Locator.click!()
      JobInspector.wait_for_visible(page)

      # Verify it defaults to no credential
      page |> JobInspector.credential_select() |> Expect.to_be_visible!()
      page |> JobInspector.credential_select() |> Expect.to_have_value!("")
    end

    Test.step "Save immediately without selecting a credential" do
      WorkflowCollab.save_workflow(page)
      WorkflowCollab.wait_for_synced(page)
    end

    Test.step "Reload and verify" do
      Page.reload!(page)

      WorkflowCollab.wait_for_react_component_loaded(page)
      WorkflowCollab.wait_for_synced(page)

      page |> job_at(1) |> Locator.click!()
      JobInspector.wait_for_visible(page)

      page |> JobInspector.credential_select() |> Expect.to_have_value!("")
    end
  end
end
