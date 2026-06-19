defmodule AbzuIde.WormChain do
  @moduledoc "Append-only WORM ledger. Sealed per action. Never deleted."
  use GenServer

  @table :abzu_worm
  @dets_file 'priv/worm-ledger.dets'

  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def seal(action, payload) do
    GenServer.call(__MODULE__, {:seal, action, payload})
  end

  def entries, do: GenServer.call(__MODULE__, :entries)

  def init(_) do
    :dets.open_file(@table, [file: @dets_file, type: :bag])
    {:ok, %{}}
  end

  def handle_call({:seal, action, payload}, _from, state) do
    ts   = System.system_time(:millisecond)
    hash = djb2_hex("#{action}:#{inspect(payload)}:#{ts}")
    id   = "#{hash}-worm-#{byte_size(inspect(payload)) |> Integer.to_string(16)}"
    entry = %{id: id, action: action, payload: payload, ts: ts, seal: id}
    :dets.insert(@table, {ts, entry})
    {:reply, entry, state}
  end

  def handle_call(:entries, _from, state) do
    entries =
      :dets.foldl(fn {_ts, e}, acc -> [e | acc] end, [], @table)
      |> Enum.sort_by(& &1.ts, :desc)
    {:reply, entries, state}
  end

  defp djb2_hex(str) do
    str
    |> String.to_charlist()
    |> Enum.reduce(5381, fn c, h -> rem(h * 33 + c, 0xFFFFFFFF) end)
    |> Integer.to_string(16)
    |> String.downcase()
    |> String.pad_leading(8, "0")
  end
end
