defmodule LightningE2E.Case do
  @moduledoc """
  The case of the `chromium` project of `playwright.config.ts`, whose device is in
  `config/runtime.exs`, plus the aliases the specs share.
  """
  use ExUnit.CaseTemplate

  using opts do
    quote do
      use Playwright.Case, unquote(opts)

      alias LightningE2E.Pages.{
        Diagram,
        JobInspector,
        LiveView,
        Login,
        Projects,
        WorkflowCollab,
        Workflows
      }

      @moduletag :e2e
    end
  end
end
