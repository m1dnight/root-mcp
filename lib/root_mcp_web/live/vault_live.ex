defmodule RootWeb.VaultLive do
  @moduledoc """
  Manages vault secrets: list names, add or overwrite, delete.

  Secret values are write-only here — they are never rendered back, and the
  browser form is the intended entry path (secrets must not travel through
  LLM conversations).
  """

  use RootWeb, :live_view

  alias Root.Vault

  @impl true
  def mount(_params, _session, socket) do
    {:ok, refresh(assign(socket, page_title: "Vault"))}
  end

  @impl true
  def handle_event("save", %{"secret" => %{"name" => name, "value" => value}}, socket) do
    name = String.trim(name)

    cond do
      name == "" ->
        {:noreply, put_flash(socket, :error, "Name must not be empty")}

      value == "" ->
        {:noreply, put_flash(socket, :error, "Value must not be empty")}

      true ->
        :ok = Vault.put(name, value)

        {:noreply,
         socket
         |> put_flash(:info, "Secret #{name} saved")
         |> refresh()}
    end
  end

  def handle_event("delete", %{"name" => name}, socket) do
    case Vault.delete(name) do
      :ok -> {:noreply, socket |> put_flash(:info, "Secret #{name} deleted") |> refresh()}
      {:error, :not_found} -> {:noreply, refresh(socket)}
    end
  end

  @spec refresh(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp refresh(socket) do
    assign(socket,
      secrets: Vault.list(),
      form: to_form(%{"name" => "", "value" => ""}, as: :secret)
    )
  end
end
