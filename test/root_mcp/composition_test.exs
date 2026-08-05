defmodule Root.CompositionTest do
  use ExUnit.Case, async: true

  # store changes notify idle MCP test sessions, which log no_sse_handler errors
  @moduletag :capture_log

  alias Root.Composition
  alias Root.Composition.Store

  @valid %{
    name: "copy_files",
    description: "Copies all files from fs1 to fs2",
    input_schema: %{"type" => "object"},
    code: "def run(args):\n    return {}"
  }

  describe "new/1" do
    test "builds a valid composition" do
      assert {:ok, %Composition{name: "copy_files"}} = Composition.new(@valid)
    end

    test "defaults the input schema to an empty object" do
      assert {:ok, %Composition{input_schema: %{"type" => "object"}}} =
               @valid |> Map.delete(:input_schema) |> Composition.new()
    end

    test "rejects bad names, empty descriptions, and code without run" do
      assert {:error, message} = Composition.new(%{@valid | name: "Bad Name!"})
      assert message =~ "snake_case"

      assert {:error, message} = Composition.new(%{@valid | description: "  "})
      assert message =~ "description"

      assert {:error, message} = Composition.new(%{@valid | code: "print('hi')"})
      assert message =~ "def run(args)"
    end
  end

  describe "Store" do
    setup do
      store = start_supervised!({Store, name: :"store_#{System.unique_integer([:positive])}"})
      {:ok, composition} = Composition.new(@valid)
      %{store: store, composition: composition}
    end

    test "puts, gets, overwrites, lists, and deletes", %{store: store, composition: composition} do
      assert Store.get(store, "copy_files") == nil
      assert :ok = Store.put(store, composition)
      assert %Composition{name: "copy_files"} = Store.get(store, "copy_files")

      updated = %{composition | description: "v2"}
      assert :ok = Store.put(store, updated)
      assert %Composition{description: "v2"} = Store.get(store, "copy_files")
      assert [%Composition{name: "copy_files"}] = Store.list(store)

      assert :ok = Store.delete(store, "copy_files")
      assert Store.list(store) == []
      assert {:error, :not_found} = Store.delete(store, "copy_files")
    end
  end
end
