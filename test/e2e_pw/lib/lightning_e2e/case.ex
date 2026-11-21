defmodule LightningE2E.Case do
  @moduledoc """
  The case of the `chromium` project of `playwright.config.ts`, plus the aliases the
  specs share.
  """
  use ExUnit.CaseTemplate

  @doc "playwright.config.ts's `chromium` project, as `parameterize:` takes it."
  def projects,
    do: [
      Playwright.Test.parameters(
        [name: "chromium"] ++ Playwright.device("Desktop Chrome")
      )
    ]

  using opts do
    opts =
      Keyword.put_new(
        opts,
        :parameterize,
        quote(do: LightningE2E.Case.projects())
      )

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
