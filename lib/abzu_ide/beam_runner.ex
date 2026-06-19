defmodule AbzuIde.BeamRunner do
  @moduledoc "Safe BEAM code evaluator. Runs user Elixir in isolated Task with timeout."

  @timeout_ms 5_000

  def run(code, bindings \\ []) do
    task = Task.async(fn -> safe_eval(code, bindings) end)
    case Task.yield(task, @timeout_ms) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} -> result
      nil            -> {:error, "Timeout after #{@timeout_ms}ms"}
    end
  end

  defp safe_eval(code, bindings) do
    try do
      {result, _bindings} = Code.eval_string(code, bindings)
      {:ok, inspect(result)}
    rescue
      e -> {:error, Exception.message(e)}
    catch
      kind, reason -> {:error, "#{kind}: #{inspect(reason)}"}
    end
  end
end
