import Config

# playwright.config.ts's `chromium` project: `use: { ...devices['Desktop Chrome'] }`, under
# every module's options. Here, as config.exs runs before Playwright.device/1 is compiled.
config :playwright, :test, Playwright.device("Desktop Chrome")
