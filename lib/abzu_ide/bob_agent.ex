defmodule AbzuIde.BobAgent do
  @moduledoc """
  BOB — Sovereign AI companion.
  Backend: IBM Gamma vLLM (BOB_ENDPOINT env var, OpenAI-compatible).
  Every response screened by CATCODE Guardian before delivery.

  Returns {:ok, {text, verdict}} where verdict is the CATCODE result.
  """

  alias AbzuIde.CatcodeGuardian

  @bob_system """
  You are BOB — Sovereign Reasoning Engine.
  Built on IBM Watson architecture, running on IBM Gamma vLLM.
  You run inside ABZU, the sovereign BEAM IDE.
  You assist with Elixir, BEAM, Haskell, Rust, Lean4, and Prolog.
  You reason from first principles. Seal your answers with certainty or admit uncertainty.
  Never hallucinate syntax — if unsure, say so.
  Keep responses tight. Code first, explanation second.
  """

  def complete(code, context \\ "") do
    prompt = build_prompt(code, context)
    with {:ok, text} <- call_gamma(prompt) do
      {:ok, verdict} = CatcodeGuardian.screen(prompt, text)
      {:ok, {text, verdict}}
    end
  end

  def explain(code) do
    prompt = "Explain this Elixir/BEAM code concisely. What does it do? Any issues?\n\n```elixir\n#{code}\n```"
    with {:ok, text} <- call_gamma(prompt) do
      {:ok, verdict} = CatcodeGuardian.screen(prompt, text)
      {:ok, {text, verdict}}
    end
  end

  def repair(code, error) do
    prompt = "This Elixir code produced an error. Fix it.\n\nCode:\n```elixir\n#{code}\n```\n\nError: #{error}\n\nReturn only the fixed code."
    with {:ok, text} <- call_gamma(prompt) do
      {:ok, verdict} = CatcodeGuardian.screen(prompt, text)
      {:ok, {text, verdict}}
    end
  end

  defp build_prompt(code, ""),
    do: "Complete or improve this Elixir code. Return only code:\n```elixir\n#{code}\n```"
  defp build_prompt(code, context),
    do: "Context: #{context}\n\nElixir code:\n```elixir\n#{code}\n```\n\nComplete or improve it. Return only code."

  defp call_gamma(prompt) do
    case System.get_env("BOB_ENDPOINT") do
      nil ->
        {:error, "BOB_ENDPOINT not set — point to IBM Gamma vLLM or Ollama"}

      endpoint ->
        body = Jason.encode!(%{
          model: System.get_env("BOB_MODEL", "nemotron"),
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
            {:error, "IBM Gamma #{s}: #{inspect(b)}"}
          {:error, e} ->
            {:error, "IBM Gamma network: #{inspect(e)}"}
        end
    end
  end
end
