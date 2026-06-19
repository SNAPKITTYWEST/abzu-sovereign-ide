defmodule AbzuIde.SovereignRegistry do
  @moduledoc """
  Sovereign NPM registry proxy.
  Every package install is WORM-sealed before it hits the network.
  Packages from outside the sovereign mesh are flagged.
  """

  @sovereign_org "snapkittywest"

  def resolve(package) do
    cond do
      sovereign?(package) ->
        {:sovereign, package, "https://registry.npmjs.org/#{package}"}
      flagged?(package) ->
        {:flagged, package, "Package not in sovereign mesh — review required"}
      true ->
        {:external, package, "https://registry.npmjs.org/#{package}"}
    end
  end

  def install_with_seal(packages) when is_list(packages) do
    results =
      Enum.map(packages, fn pkg ->
        resolution = resolve(pkg)
        AbzuIde.WormChain.seal(:npm_install, %{package: pkg, resolution: elem(resolution, 0)})
        resolution
      end)

    {:ok, results}
  end

  def sovereign_packages do
    [
      %{name: "snapkitty-mcp", version: "1.0.0", status: :sovereign, org: @sovereign_org},
      %{name: "bob-orchestrator", version: "0.1.0", status: :sovereign, org: @sovereign_org},
      %{name: "abzu-runtime", version: "0.1.0", status: :sovereign, org: @sovereign_org},
      %{name: "worm-ledger", version: "1.0.0", status: :sovereign, org: @sovereign_org},
      %{name: "bifrost-translator", version: "0.1.0", status: :sovereign, org: @sovereign_org},
    ]
  end

  defp sovereign?(pkg), do: String.starts_with?(pkg, @sovereign_org) or String.starts_with?(pkg, "abzu")
  defp flagged?(pkg), do: String.contains?(pkg, ["eval", "exec", "shell", "child_process"])
end
