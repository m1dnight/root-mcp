defmodule RootWeb.PythonHighlighter do
  @moduledoc """
  Minimal server-side Python syntax highlighting for read-only display:
  comments, strings, keywords, and numbers. No dependencies.
  """

  @keywords ~w(and as assert async await break class continue def del elif else
    except finally for from global if import in is lambda nonlocal not or pass
    raise return try while with yield True False None)

  @keyword_set MapSet.new(@keywords)

  @token ~r/"""(?:[^"\\]|\\.|"(?!""))*"""|'''(?:[^'\\]|\\.|'(?!''))*'''|"(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*'|#[^\n]*|\b(?:#{Enum.join(@keywords, "|")})\b|\b\d[\d_]*(?:\.\d+)?\b/

  @colors %{
    comment: "color:#8b949e;font-style:italic",
    string: "color:#a5d6ff",
    keyword: "color:#ff7b72",
    number: "color:#f2cc60"
  }

  @doc "Highlights Python source into safe HTML (spans with inline styles)."
  @spec highlight(String.t()) :: Phoenix.HTML.safe()
  def highlight(code) when is_binary(code) do
    @token
    |> Regex.split(code, include_captures: true)
    |> Enum.map(&render_token/1)
    |> Phoenix.HTML.raw()
  end

  @spec render_token(String.t()) :: iodata()
  defp render_token(token) do
    case classify(token) do
      :plain -> escape(token)
      kind -> [~s(<span style="), @colors[kind], ~s(">), escape(token), "</span>"]
    end
  end

  @spec classify(String.t()) :: :comment | :string | :keyword | :number | :plain
  defp classify("#" <> _), do: :comment
  defp classify(<<q, _::binary>>) when q in [?", ?'], do: :string

  defp classify(<<d, _::binary>> = token) when d in ?0..?9,
    do: if(number?(token), do: :number, else: :plain)

  defp classify(token), do: if(MapSet.member?(@keyword_set, token), do: :keyword, else: :plain)

  @spec number?(String.t()) :: boolean()
  defp number?(token), do: token =~ ~r/^\d[\d_]*(?:\.\d+)?$/

  @spec escape(String.t()) :: iodata()
  defp escape(text), do: Plug.HTML.html_escape_to_iodata(text)
end
