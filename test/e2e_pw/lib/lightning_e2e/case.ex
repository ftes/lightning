defmodule LightningE2E.Case do
  @moduledoc """
  The `chromium` project of `playwright.config.ts`
  (`use: { ...devices['Desktop Chrome'] }`), plus the aliases the specs share.
  """
  use ExUnit.CaseTemplate

  using opts do
    quote do
      use Playwright.Case, unquote(opts)
      use Playwright.Test, Playwright.device("Desktop Chrome")

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
