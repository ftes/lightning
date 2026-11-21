import Config

port = System.get_env("PORT", "4003")

# playwright.config.ts: `use.baseURL`, `use.trace: 'on-first-retry'`.
config :playwright, :test,
  context_options: [base_url: "http://localhost:#{port}"],
  trace: :on_first_retry
