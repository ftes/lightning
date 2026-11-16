defmodule LightningE2E.Case do
  @moduledoc """
  The `chromium` project of `playwright.config.ts`
  (`use: { ...devices['Desktop Chrome'] }`), plus the aliases the specs share.
  """
  use ExUnit.CaseTemplate
  use Playwright.Test

  alias Playwright.{Browser, BrowserContext}
  alias Playwright.Test.BrowserPool

  using opts do
    quote do
      use Playwright.Test, unquote(opts)
      alias Playwright.{Browser, BrowserContext, Expect, Locator, Page}
      alias Playwright.Test
      require Playwright.Test

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

  setup_all do
    %{browser: BrowserPool.browser()}
  end

  setup %{browser: browser} do
    device =
      Map.fetch!(
        Playwright.devices(BrowserPool.playwright(browser)),
        "Desktop Chrome"
      )

    context = Browser.new_context!(browser, device)
    %{context: context, page: BrowserContext.new_page!(context)}
  end
end
