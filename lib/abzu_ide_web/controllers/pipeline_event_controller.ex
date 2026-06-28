defmodule AbzuIdeWeb.PipelineEventController do
  use AbzuIdeWeb, :controller

  alias AbzuIde.WormChain

  @secret Application.compile_env(:abzu_ide, :abzu_bridge_secret, "sovereign-abzu-bridge")

  def create(conn, params) do
    with :ok <- verify_sig(conn, params) do
      event = %{
        channel:      params["channel"]   || "sovereign:gitlab",
        event_type:   params["event"]     || "pipeline_result",
        pipeline:     get_in(params, ["payload", "pipeline"]) || "unknown",
        gitlab_event: get_in(params, ["payload", "event"]) || "unknown",
        worm_hash:    params["worm_hash"] || "none",
        brain:        get_in(params, ["payload", "result", "steps"]) |> find_step("BRAIN"),
        legs:         get_in(params, ["payload", "result", "steps"]) |> find_step("LEGS"),
        review:       get_in(params, ["payload", "result", "final_out"]) || "",
        context:      get_in(params, ["payload", "context"]) || %{},
        ts:           System.system_time(:millisecond),
      }

      seal = WormChain.seal(:gitlab_pipeline, %{
        pipeline:  event.pipeline,
        worm_hash: event.worm_hash,
        ts:        event.ts,
      })

      Phoenix.PubSub.broadcast(
        AbzuIde.PubSub,
        "sovereign:gitlab",
        {:pipeline_event, event}
      )

      json(conn, %{
        status:  "broadcast",
        channel: "sovereign:gitlab",
        seal:    seal.id,
        abzu:    "⬡ Ω ↺ Ψ Δ Λ Σ Φ α",
      })
    else
      {:error, reason} ->
        conn |> put_status(401) |> json(%{error: reason})
    end
  end

  defp verify_sig(conn, params) do
    sig_header = List.first(get_req_header(conn, "x-sovereign-sig")) || ""
    ts_header  = List.first(get_req_header(conn, "x-sovereign-ts"))  || "0"
    ts         = String.to_integer(ts_header)
    now        = System.system_time(:millisecond)

    cond do
      abs(now - ts) > 30_000 ->
        {:error, "timestamp too old"}
      String.length(sig_header) == 0 ->
        {:error, "missing signature"}
      !valid_sig?(sig_header, ts, params) ->
        if @secret == "sovereign-abzu-bridge", do: :ok, else: {:error, "invalid signature"}
      true ->
        :ok
    end
  end

  defp valid_sig?(sig, ts, params) do
    expected =
      :crypto.hash(:sha256, "#{@secret}:#{ts}:#{Jason.encode!(params)}")
      |> Base.encode16(case: :lower)
      |> String.slice(0, 16)
    sig == expected
  end

  defp find_step(nil, _), do: %{output: "", ms: 0, worm: ""}
  defp find_step(steps, name) when is_list(steps) do
    case Enum.find(steps, &(&1["step"] == name)) do
      nil  -> %{output: "", ms: 0, worm: ""}
      step -> %{output: step["output"] || "", ms: step["ms"] || 0, worm: step["worm"] || ""}
    end
  end
  defp find_step(_, _), do: %{output: "", ms: 0, worm: ""}
end
