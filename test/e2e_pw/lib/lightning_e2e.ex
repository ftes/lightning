defmodule LightningE2E do
  @moduledoc """
  Port of `e2e-helper.ts`, `test-data.ts`, `global.setup.ts` and the `webServer`
  of `playwright.config.ts`: the `bin/e2e` wrapper (reset, describe, ...) and the
  memoised test data.
  """

  # `binPath` is `<assets>/../bin/e2e`; this project is at `<root>/test/e2e_pw`.
  @bin_path Path.expand("../../../bin/e2e", __DIR__)

  def bin_path, do: @bin_path
  def port, do: System.get_env("PORT", "4003")

  # e2e-helper.ts `executeCommand`: `execSync("bin/e2e <command>")` with a
  # 30 s default timeout.
  defp execute(args, timeout \\ 30_000) do
    task =
      Task.async(fn ->
        System.cmd(@bin_path, args, stderr_to_stdout: true, env: server_env())
      end)

    case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, {output, 0}} ->
        String.trim(output)

      {:ok, {output, status}} ->
        raise "E2E command '#{Enum.join(args, " ")}' failed (#{status}): #{output}"

      nil ->
        raise "E2E command '#{Enum.join(args, " ")}' timed out after #{timeout}ms."
    end
  end

  # Mix runs this project in the `test` env, bin/e2e's server is `dev`.
  def server_env, do: [{"MIX_ENV", "dev"}, {"PORT", port()}]

  @doc "Get current database state as JSON."
  def describe do
    output = execute(["describe"])

    if output in ["", "null"] do
      raise "E2E describe command returned null or empty response. Run \"bin/e2e setup\"."
    end

    Jason.decode!(output)
  end

  @doc "Reset database to clean state using snapshot (fast)."
  def reset(opts \\ []) do
    args = if opts[:quiet], do: ["reset", "--quiet"], else: ["reset"]
    execute(args, 60_000)
    :ok
  end

  @doc "Enable experimental features for a user (defaults to editor@openfn.org)."
  def enable_experimental_features(user_email \\ "editor@openfn.org") do
    args =
      if user_email == "editor@openfn.org",
        do: ["enable-experimental-features"],
        else: ["enable-experimental-features", user_email]

    execute(args)
    :ok
  end

  @doc "Check if e2e infrastructure is available."
  def available? do
    execute(["help"], 5_000)
    true
  rescue
    _ -> false
  end

  # global.setup.ts: runs once before all suites.
  def global_setup do
    IO.puts("Setting up E2E test environment...")

    unless available?() do
      raise "E2E infrastructure not available. Make sure bin/e2e script exists and " <>
              "PostgreSQL is running. Run \"bin/e2e setup\" to initialize the database."
    end

    reset(quiet: true)
    reset_test_data_cache()
    IO.puts("E2E environment ready for testing!")
  end

  # webServer: command `bin/e2e start`, url, reuseExistingServer: !process.env.CI,
  # timeout: 60 s.
  def start_web_server do
    url = "http://localhost:#{port()}"

    if !System.get_env("CI") && url_up?(url) do
      :reused
    else
      parent = self()

      spawn_link(fn ->
        port =
          Port.open({:spawn_executable, @bin_path}, [
            :binary,
            :exit_status,
            :stderr_to_stdout,
            args: ["start"],
            env:
              for(
                {k, v} <- server_env(),
                do: {String.to_charlist(k), String.to_charlist(v)}
              )
          ])

        send(parent, :server_started)
        drain(port)
      end)

      receive do
        :server_started -> :ok
      end

      wait_for_url(url, System.monotonic_time(:millisecond) + 60_000)
      :started
    end
  end

  defp drain(port) do
    receive do
      {^port, {:data, _}} -> drain(port)
      {^port, {:exit_status, _}} -> :ok
    end
  end

  def stop_web_server,
    do:
      System.cmd(@bin_path, ["stop"], env: server_env(), stderr_to_stdout: true)

  defp wait_for_url(url, deadline) do
    cond do
      url_up?(url) ->
        :ok

      System.monotonic_time(:millisecond) > deadline ->
        raise "Timed out waiting 60000ms from config.webServer."

      true ->
        Process.sleep(250) && wait_for_url(url, deadline)
    end
  end

  # Playwright accepts 200-399 and 400-403 as "up".
  defp url_up?(url) do
    case :httpc.request(
           :get,
           {String.to_charlist(url), []},
           [timeout: 2_000, autoredirect: false],
           []
         ) do
      {:ok, {{_, status, _}, _, _}} when status in 200..403 -> true
      _ -> false
    end
  end

  ## test-data.ts

  @password "welcome12345"

  @doc "Test data shaped from `bin/e2e describe`, memoised (`getTestData`)."
  def test_data do
    case :persistent_term.get({__MODULE__, :test_data}, nil) do
      nil ->
        data = shape_database_state(describe())
        :persistent_term.put({__MODULE__, :test_data}, data)
        data

      data ->
        data
    end
  end

  def reset_test_data_cache, do: :persistent_term.erase({__MODULE__, :test_data})

  defp shape_database_state(db_state) do
    projects = db_state["projects"] || []
    users = db_state["users"] || []
    workflows = db_state["workflows"] || []

    for {list, what} <- [
          {projects, "projects"},
          {users, "users"},
          {workflows, "workflows"}
        ],
        list == [],
        do:
          raise(
            "No #{what} found in database. Run \"bin/e2e setup\" to create demo data."
          )

    user = fn email ->
      case Enum.find(users, &(&1["email"] == email)) do
        nil -> nil
        u -> %{email: u["email"], password: @password, id: u["id"]}
      end
    end

    project = fn name ->
      Enum.find(projects, &(&1["name"] == name)) ||
        raise "#{name} not found in database."
    end

    workflow = fn project ->
      w =
        Enum.find(workflows, &(&1["project_id"] == project["id"])) ||
          raise "workflow of #{project["name"]} not found in database."

      %{id: w["id"], name: w["name"], project_id: w["project_id"]}
    end

    openhie = project.("openhie-project")
    dhis2 = project.("dhis2-project")

    %{
      users: %{
        admin: user.("demo@openfn.org") || raise("Admin user not found"),
        editor: user.("editor@openfn.org") || raise("Editor user not found"),
        viewer: user.("viewer@openfn.org") || raise("Viewer user not found"),
        super: user.("super@openfn.org")
      },
      projects: %{
        openhie: %{id: openhie["id"], name: openhie["name"]},
        dhis2: %{id: dhis2["id"], name: dhis2["name"]}
      },
      workflows: %{openhie: workflow.(openhie), dhis2: workflow.(dhis2)}
    }
  end
end
