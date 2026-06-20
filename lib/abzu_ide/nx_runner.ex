defmodule AbzuIde.NxRunner do
  @moduledoc """
  Nx Array Runner — tensor math on the BEAM.
  Wraps user code in an Nx context and executes via BeamRunner.
  APL-style array operations in Elixir.
  Every result WORM-sealed.
  """

  alias AbzuIde.{BeamRunner, WormChain}

  @prelude """
  import Nx
  import Nx, only: [tensor: 1, tensor: 2]
  alias Nx.LinAlg
  """

  @examples """
  NB. QUICK REFERENCE — Nx Array Language
  NB. tensor([1,2,3,4,5])                    # create array
  NB. Nx.sum(t)                               # sum all elements
  NB. Nx.multiply(t, t)                       # element-wise multiply
  NB. Nx.dot(a, b)                            # dot product
  NB. Nx.reshape(t, {2,3})                    # reshape
  NB. Nx.iota({5})                            # [0,1,2,3,4]
  NB. Nx.LinAlg.norm(t)                       # magnitude
  """

  def run(code) do
    full_code = @prelude <> "\n" <> code
    case BeamRunner.run(full_code) do
      {:ok, result} ->
        seal = WormChain.seal(:nx_run, %{code_hash: hash(code)})
        {:ok, result, seal}
      {:error, err} ->
        seal = WormChain.seal(:nx_error, %{code_hash: hash(code), error: err})
        {:error, err, seal}
    end
  end

  def examples, do: @examples

  defp hash(str) do
    :crypto.hash(:sha256, str) |> Base.encode16(case: :lower) |> binary_part(0, 8)
  end
end
