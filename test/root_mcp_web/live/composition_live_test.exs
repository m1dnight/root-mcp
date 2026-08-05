defmodule RootWeb.CompositionLiveTest do
  use RootWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Root.Composition
  alias Root.Composition.Store

  @moduletag :capture_log

  setup do
    {:ok, composition} =
      Composition.new(%{
        name: "greet",
        description: "Greets someone by name",
        input_schema: %{
          "type" => "object",
          "properties" => %{"who" => %{"type" => "string"}},
          "required" => ["who"]
        },
        code: "# say hi\ndef run(args):\n    return {\"greeting\": \"hi \" + args[\"who\"]}"
      })

    :ok = Store.put(composition)
    on_exit(fn -> Store.delete("greet") end)
    :ok
  end

  test "lists compositions and shows the selected one's code", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/compositions")

    assert has_element?(view, "#composition-greet")

    view
    |> element("#composition-greet a")
    |> render_click()

    assert_patch(view, ~p"/compositions/greet")

    assert has_element?(view, "#composition-code")
    code_html = view |> element("#composition-code") |> render()
    assert code_html =~ "def"
    assert code_html =~ "say hi"
    assert code_html =~ "<span"

    assert view |> element("#composition-schema") |> render() =~ "who"
  end

  test "live-updates when the store changes", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/compositions")

    {:ok, second} =
      Composition.new(%{
        name: "later",
        description: "added while the page is open",
        code: "def run(args):\n    return {}"
      })

    :ok = Store.put(second)
    on_exit(fn -> Store.delete("later") end)

    _ = :sys.get_state(view.pid)
    assert has_element?(view, "#composition-later")

    :ok = Store.delete("later")
    _ = :sys.get_state(view.pid)
    refute render(view) =~ "composition-later"
  end
end
