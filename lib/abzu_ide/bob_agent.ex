defmodule AbzuIde.BobAgent do
  @moduledoc """
  BOB — Sovereign AI companion.
  Backend: IBM Gamma (vLLM) when BOB_ENDPOINT is set.
  Falls back to Anthropic Claude (ANTHROPIC_API_KEY).
  """

  @bob_system """
  You are BOB — Sovereign Reasoning Engine.
  You run inside ABZU, the sovereign BEAM IDE.
  You assist with Elixir, BEAM, Haskell, Rust, Lean4, and Prolog.
  You reason from first principles. You seal your answers with certainty or admit uncertainty.
  You never hallucinate syntax — if unsure, say so.
  Keep responses tight. Code first, explanation second.
  """

  def complete(code, context \\ "") do
    prompt = build_prompt(code, context)
    backend = System.get_env("BOB_ENDPOINT")

    if backend do
      call_vllm(backend, prompt)
    else
      call_anthropic(prompt)
    end
  end

  def explain(code) do
    prompt = "Explain this Elixir/BEAM code concisely. What does it do? Any issues?\n\n```elixir\n#{code}\n```"
    call_anthropic(prompt)
  end

  def repair(code, error) do
    prompt = "This Elixir code produced an error. Fix it.\n\nCode:\n```elixir\n#{code}\n```\n\nError: #{error}\n\nReturn only the fixed code, no explanation."
    call_anthropic(prompt)
  end

  defp build_prompt(code, "") do
    "Complete or improve this Elixir code. Return only code:\n```elixir\n#{code}\n```"
  end
  defp build_prompt(code, context) do
    "Context: #{context}\n\nElixir code:\n```elixir\n#{code}\n```\n\nComplete or improve it. Return only code."
  end

  defp call_anthropic(prompt) do
    api_key = System.get_env("ANTHROPIC_API_KEY") || ""
    body = Jason.encode!(%{
      model: "claude-haiku-4-5-20251001",
      max_tokens: 1024,
      system: @bob_system,
      messages: [%{role: "user", content: prompt}]
    })

    case Req.post("https://api.anthropic.com/v1/messages",
      body: body,
      headers: [
        {"x-api-key", api_key},
        {"anthropic-version", "2023-06-01"},
        {"content-type", "application/json"}
      ]
    ) do
      {:ok, %{status: 200, body: body}} ->
        text = get_in(body, ["content", Access.at(0), "text"]) || ""
        {:ok, text}
      {:ok, %{status: s, body: b}} ->
        {:error, "API #{s}: #{inspect(b)}"}
      {:error, e} ->
        {:error, "Network: #{inspect(e)}"}
    end
  end

  defp call_vllm(endpoint, prompt) do
    body = Jason.encode!(%{
      model: System.get_env("BOB_MODEL", "ibm-granite-3b"),
      messages: [
        %{role: "system", content: @bob_system},
        %{role: "user", content: prompt}
      ],
      max_tokens: 1024,
      temperature: 0.2
    })

    case Req.post("#{endpoint}/v1/chat/completions",
      body: body,
      headers: [{"content-type", "application/json"}]
    ) do
      {:ok, %{status: 200, body: body}} ->
        text = get_in(body, ["choices", Access.at(0), "message", "content"]) || ""
        {:ok, text}
      {:ok, %{status: s, body: b}} ->
        {:error, "vLLM #{s}: #{inspect(b)}"}
      {:error, e} ->
        {:error, "vLLM network: #{inspect(e)}"}
    end
  end
end
