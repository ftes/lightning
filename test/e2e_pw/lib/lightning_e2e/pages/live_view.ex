defmodule LightningE2E.Pages.LiveView do
  @moduledoc """
  Port of `pages/base/liveview.page.ts`: common functionality for Phoenix
  LiveView pages.
  """
  alias Playwright.{Expect, Keyboard, Locator, Page}

  @phoenix_main "div[data-phx-main]"
  @flash_message ~s|[id^="flash-"][phx-hook="Flash"]|

  def click_menu_item(page, item_text) do
    page
    |> Page.locator("#side-menu")
    |> Locator.get_by_role(:link, name: item_text)
    |> Locator.click!()
  end

  @doc """
  Wait for the Phoenix LiveView connection to be established.

  Important when navigating between different LiveView sessions: waiting for the
  "phx-connected" class ensures the LiveView is ready to handle interactions.
  """
  def wait_for_connected(page) do
    locator = Page.locator(page, @phoenix_main)
    Expect.to_be_visible!(locator)
    Expect.to_contain_class!(locator, "phx-connected")
  end

  def expect_flash_message(page, text) do
    page
    |> Page.locator(@flash_message)
    |> Locator.filter(has_text: text)
    |> Expect.to_be_visible!()
  end

  def wait_for_socket_settled(page) do
    Page.wait_for_function!(page, """
    () => {
      return new Promise(resolve => {
        window.liveSocket.socket.ping(resolve);
      });
    }
    """)
  end

  @doc """
  Wait for Phoenix LiveView event handlers to be attached to an element.
  Useful when moving between LiveView sessions.
  """
  def wait_for_event_attached(
        page,
        locator,
        event_type \\ "click",
        timeout \\ 5000
      ) do
    # First get the element handle to use in waitForFunction
    element_handle = Locator.element_handle!(locator)

    Page.wait_for_function!(
      page,
      """
      ({ elementHandle, eventType }) => {
        // Check for Phoenix LiveView click handler
        if (eventType === 'click' && elementHandle.hasAttribute('phx-click')) {
          // For Phoenix LiveView, check if the main container is connected
          const isPhxConnected = document
            .querySelector('[data-phx-main]')
            ?.classList.contains('phx-connected');
          return isPhxConnected;
        }

        // For other event types, check for actual event listeners
        const listeners = elementHandle.getEventListeners?.() || {};
        return listeners[eventType] && listeners[eventType].length > 0;
      }
      """,
      %{elementHandle: element_handle, eventType: event_type},
      timeout: timeout
    )
  end

  def keyboard_press(page, key),
    do: page |> Page.keyboard() |> Keyboard.press!(key)
end
