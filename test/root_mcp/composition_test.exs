defmodule Root.CompositionTest do
  use Root.DataCase, async: false

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
      {:ok, composition} = Composition.new(@valid)
      %{composition: composition}
    end

    test "puts, gets, overwrites, lists, and deletes", %{composition: composition} do
      assert Store.get("copy_files") == nil
      assert :ok = Store.put(composition)
      assert %Composition{name: "copy_files"} = Store.get("copy_files")

      updated = %{composition | description: "v2"}
      assert :ok = Store.put(updated)
      assert %Composition{description: "v2"} = Store.get("copy_files")
      assert [%Composition{name: "copy_files"}] = Store.list()

      assert :ok = Store.delete("copy_files")
      assert Store.list() == []
      assert {:error, :not_found} = Store.delete("copy_files")
    end

    test "round-trips the input schema through the database", %{composition: composition} do
      schema = %{
        "type" => "object",
        "properties" => %{"n" => %{"type" => "number"}},
        "required" => ["n"]
      }

      assert :ok = Store.put(%{composition | input_schema: schema})
      assert %Composition{input_schema: ^schema} = Store.get("copy_files")
    end
  end
end
