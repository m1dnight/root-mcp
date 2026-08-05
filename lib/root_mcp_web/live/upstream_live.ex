defmodule RootWeb.UpstreamLive do
  @moduledoc """
  Manages persisted upstream configs: list with running status, add, edit,
  enable/disable, delete. The Manager reacts to every change, so saving a
  config is what starts (or stops) the upstream.
  """

  use RootWeb, :live_view

  alias Root.MCP.Upstream
  alias Root.MCP.Upstream.Config
  alias Root.MCP.Upstream.Config.Store

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Root.PubSub, Store.topic())
      # upstreams start/crash asynchronously; keep the status dots honest
      :timer.send_interval(2000, :refresh_status)
    end

    {:ok, socket |> assign(page_title: "Upstreams") |> reset_form() |> refresh()}
  end

  @impl true
  def handle_event("edit", %{"id" => id}, socket) do
    case Store.get(id) do
      nil -> {:noreply, socket}
      config -> {:noreply, edit_form(socket, config)}
    end
  end

  def handle_event("cancel", _params, socket) do
    {:noreply, reset_form(socket)}
  end

  def handle_event("save", %{"config" => params}, socket) do
    with {:ok, env} <- parse_env(params["env"]),
         {:ok, args} <- parse_args(params["args"]),
         {:ok, config} <-
           Config.new(%{
             id: socket.assigns.editing || String.trim(params["id"] || ""),
             command: String.trim(params["command"] || ""),
             args: args,
             env: env,
             cwd: presence(params["cwd"]),
             enabled: params["enabled"] == "true"
           }) do
      :ok = Store.put(config)

      {:noreply,
       socket
       |> put_flash(:info, "Upstream #{config.id} saved")
       |> reset_form()
       |> refresh()}
    else
      {:error, message} -> {:noreply, put_flash(socket, :error, message)}
    end
  end

  def handle_event("toggle", %{"id" => id}, socket) do
    with %Config{} = config <- Store.get(id) do
      :ok = Store.put(%{config | enabled: not config.enabled})
    end

    {:noreply, refresh(socket)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    Store.delete(id)
    {:noreply, socket |> put_flash(:info, "Upstream #{id} deleted") |> reset_form() |> refresh()}
  end

  @impl true
  def handle_info(:upstream_configs_changed, socket), do: {:noreply, refresh(socket)}
  def handle_info(:refresh_status, socket), do: {:noreply, refresh(socket)}

  @spec refresh(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp refresh(socket) do
    assign(socket, configs: Store.list(), running: MapSet.new(Upstream.list()))
  end

  @spec reset_form(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp reset_form(socket) do
    assign(socket,
      editing: nil,
      form: build_form(%{"env" => "{}", "enabled" => "true"})
    )
  end

  @spec edit_form(Phoenix.LiveView.Socket.t(), Config.t()) :: Phoenix.LiveView.Socket.t()
  defp edit_form(socket, %Config{} = config) do
    assign(socket,
      editing: config.id,
      form:
        build_form(%{
          "id" => config.id,
          "command" => config.command,
          "args" => Enum.map_join(config.args, "\n", &format_arg/1),
          "env" => Jason.encode!(config.env, pretty: true),
          "cwd" => config.cwd || "",
          "enabled" => to_string(config.enabled)
        })
    )
  end

  @spec build_form(map()) :: Phoenix.HTML.Form.t()
  defp build_form(params), do: to_form(params, as: :config)

  @spec parse_env(String.t() | nil) :: {:ok, map()} | {:error, String.t()}
  defp parse_env(json) do
    case JSON.decode(json || "{}") do
      {:ok, %{} = env} -> {:ok, env}
      _invalid -> {:error, "env must be a valid JSON object"}
    end
  end

  @spec parse_args(String.t() | nil) :: {:ok, [Config.template_value()]} | {:error, String.t()}
  defp parse_args(text) do
    (text || "")
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.reduce_while({:ok, []}, fn line, {:ok, args} ->
      case parse_arg(line) do
        {:ok, arg} -> {:cont, {:ok, [arg | args]}}
        :error -> {:halt, {:error, "invalid JSON reference in args: #{line}"}}
      end
    end)
    |> case do
      {:ok, args} -> {:ok, Enum.reverse(args)}
      error -> error
    end
  end

  # lines starting with { are JSON references, everything else is literal
  @spec parse_arg(String.t()) :: {:ok, Config.template_value()} | :error
  defp parse_arg("{" <> _rest = line) do
    case JSON.decode(line) do
      {:ok, %{} = reference} -> {:ok, reference}
      _invalid -> :error
    end
  end

  defp parse_arg(line), do: {:ok, line}

  @spec format_arg(Config.template_value()) :: String.t()
  defp format_arg(arg) when is_binary(arg), do: arg
  defp format_arg(%{} = reference), do: JSON.encode!(reference)

  @spec presence(String.t() | nil) :: String.t() | nil
  defp presence(value) do
    case String.trim(value || "") do
      "" -> nil
      trimmed -> trimmed
    end
  end
end
