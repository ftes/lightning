defmodule LightningE2E.Pages.JobInspector do
  @moduledoc "Port of `pages/components/job-inspector.page.ts`: the job inspector panel."
  alias Playwright.{Locator, Page}

  def container(page), do: Page.locator(page, ~s|[data-testid="job-inspector"]|)

  def name_input(page),
    do: page |> container() |> Locator.locator(~s|input[name="name"]|)

  def adaptor_package_select(page),
    do:
      page |> container() |> Locator.locator(~s|select[name="adaptor_package"]|)

  def adaptor_version_select(page),
    do: page |> container() |> Locator.locator(~s|select[name="adaptor"]|)

  @doc "The credential select holds project and keychain credentials, in optgroups."
  def credential_select(page),
    do: page |> container() |> Locator.locator(~s|select[name="credential_id"]|)

  def set_name(page, name), do: page |> name_input() |> Locator.fill!(name)

  def select_adaptor_package(page, package_name),
    do: page |> adaptor_package_select() |> Locator.select_option!(package_name)

  def select_adaptor_version(page, version),
    do: page |> adaptor_version_select() |> Locator.select_option!(version)

  def select_credential(page, credential_id),
    do: page |> credential_select() |> Locator.select_option!(credential_id)

  @doc "Select the placeholder option (empty string) to indicate no credential."
  def clear_credential(page),
    do: page |> credential_select() |> Locator.select_option!("")

  def get_selected_credential(page),
    do: page |> credential_select() |> Locator.input_value!()

  def wait_for_visible(page),
    do: page |> container() |> Locator.wait_for!(state: :visible)

  def wait_for_hidden(page),
    do: page |> container() |> Locator.wait_for!(state: :hidden)
end
