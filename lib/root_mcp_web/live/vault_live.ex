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
    {:ok, socket |> assign(page_title: "Vault") |> reset_form() |> refresh()}
  end

  @impl true
  def handle_event("reveal", %{"name" => name}, socket) do
    case Vault.fetch(name) do
      {:ok, value} -> {:noreply, assign(socket, revealed: {name, value})}
      :error -> {:noreply, refresh(socket)}
    end
  end

  def handle_event("hide", _params, socket) do
    {:noreply, assign(socket, revealed: nil)}
  end

  def handle_event("edit", %{"name" => name}, socket) do
    {:noreply, assign(socket, editing: name, form: build_form(name))}
  end

  def handle_event("cancel", _params, socket) do
    {:noreply, reset_form(socket)}
  end

  def handle_event("save", %{"secret" => %{"name" => name, "value" => value}}, socket) do
    name = String.trim(socket.assigns.editing || name)

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
         |> reset_form()
         |> refresh()}
    end
  end

  def handle_event("delete", %{"name" => name}, socket) do
    case Vault.delete(name) do
      :ok ->
        {:noreply,
         socket |> put_flash(:info, "Secret #{name} deleted") |> reset_form() |> refresh()}

      {:error, :not_found} ->
        {:noreply, refresh(socket)}
    end
  end

  @spec refresh(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp refresh(socket) do
    assign(socket, secrets: Vault.list())
  end

  @spec reset_form(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp reset_form(socket) do
    assign(socket, editing: nil, revealed: nil, form: build_form(""))
  end

  @spec build_form(String.t()) :: Phoenix.HTML.Form.t()
  defp build_form(name), do: to_form(%{"name" => name, "value" => ""}, as: :secret)
end
