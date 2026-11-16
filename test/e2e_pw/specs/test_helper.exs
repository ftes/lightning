# Quiet the driver: playwright_ex logs every API call at :debug.
Logger.configure(level: :warning)

# playwright.config.ts `webServer`, then global.setup.ts.
LightningE2E.start_web_server()
ExUnit.after_suite(fn _ -> LightningE2E.stop_web_server() end)
LightningE2E.global_setup()

# Playwright Test's default test timeout is 30 s (ExUnit's is 60 s).
ExUnit.start(timeout: 30_000)
