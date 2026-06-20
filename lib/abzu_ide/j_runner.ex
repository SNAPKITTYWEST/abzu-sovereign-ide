defmodule AbzuIde.JRunner do
  @moduledoc """
  J Language Shell — array programming in ABZU.
  Calls jconsole via Port if installed.
  J is ASCII APL — pure verb-noun composition, no loops.

  Install J: https://jsoftware.com/products/j-software-downloads/
  Or try online: https://jsoftware.com/#tryj

  Key syntax:
    +/ i. 101        NB. sum 1 to 100 = 5050
    (1 + %: 5) % 2   NB. golden ratio φ
    =/ i. 4          NB. 4x4 identity matrix
    (, +/)^: 8 ] 0 1 NB. fibonacci sequence
  """

  alias AbzuIde.WormChain

  @not_installed """
  J NOT INSTALLED

  J is a free array language — ASCII APL, pure math composition.
  Download: jsoftware.com/products/j-software-downloads/
  Try online: jsoftware.com/#tryj

  After installing, restart ABZU and J will run here.

  QUICK J REFERENCE:
    NB.              comment
    +/ i. 101        sum 1 to 100
    (1 + %: 5) % 2   golden ratio
    (, +/)^: 8 ] 0 1 fibonacci
    =/ i. 4          identity matrix
    phi ^ - i. 10    phi contraction sequence
    +/ % #           average (fork — no variable names)
    i. 3 4           3x4 matrix of indices
    $ arr            shape of array
    # arr            count
    |. arr           reverse
    */               product (fold with multiply)
  """

  def run(code) do
    case find_jconsole() do
      nil ->
        WormChain.seal(:j_not_installed, %{})
        {:error, @not_installed}

      jconsole ->
        run_with_jconsole(jconsole, code)
    end
  end

  def installed? do
    not is_nil(find_jconsole())
  end

  defp find_jconsole do
    # Check common install locations
    candidates = [
      System.find_executable("jconsole"),
      System.find_executable("jconsole.exe"),
      "C:/Program Files/j9.5/bin/jconsole.exe",
      "C:/j9.5/bin/jconsole.exe",
      "/usr/local/bin/jconsole",
      "/opt/j9.5/bin/jconsole"
    ]
    Enum.find(candidates, fn
      nil -> false
      path -> File.exists?(path)
    end)
  end

  defp run_with_jconsole(jconsole, code) do
    tmp = Path.join(System.tmp_dir!(), "abzu_j_#{:rand.uniform(99999)}.ijs")
    # J script: run code then exit
    File.write!(tmp, code <> "\nexit''")

    case System.cmd(jconsole, [tmp], stderr_to_stdout: true, timeout: 10_000) do
      {output, 0} ->
        result = String.trim(output)
        seal = WormChain.seal(:j_run, %{code_hash: hash(code)})
        File.rm(tmp)
        {:ok, result, seal}

      {output, _code} ->
        err = String.trim(output)
        seal = WormChain.seal(:j_error, %{error: err})
        File.rm(tmp)
        {:error, err, seal}
    end
  end

  defp hash(str) do
    :crypto.hash(:sha256, str) |> Base.encode16(case: :lower) |> binary_part(0, 8)
  end
end
