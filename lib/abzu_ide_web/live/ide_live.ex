defmodule AbzuIdeWeb.IdeLive do
  use AbzuIdeWeb, :live_view

  alias AbzuIde.{BeamRunner, BobAgent, WormChain, SovereignRegistry}

  @default_code """
  # ABZU Sovereign BEAM IDE
  # Write Elixir. BOB is watching. CATCODE is screening.

  defmodule Hello do
    def greet(name), do: "Hello, #{name}. The chain remembers."
  end

  IO.puts Hello.greet("sovereign")
  """

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:code, @default_code)
     |> assign(:output, nil)
     |> assign(:error, nil)
     |> assign(:bob_response, nil)
     |> assign(:bob_verdict, nil)
     |> assign(:bob_loading, false)
     |> assign(:active_tab, :editor)
     |> assign(:worm_entries, [])
     |> assign(:registry_packages, SovereignRegistry.sovereign_packages())
     |> assign(:run_seal, nil)}
  end

  def handle_event("code_change", %{"code" => code}, socket) do
    {:noreply, assign(socket, :code, code)}
  end

  def handle_event("run", _params, socket) do
    code = socket.assigns.code

    case BeamRunner.run(code) do
      {:ok, result} ->
        seal = WormChain.seal(:beam_run, %{code_hash: hash(code), result: result})
        entries = WormChain.entries()
        {:noreply,
         socket
         |> assign(:output, result)
         |> assign(:error, nil)
         |> assign(:run_seal, seal)
         |> assign(:worm_entries, entries)
         |> push_event("abzu:beam_run", %{seal: seal.id, ok: true})}

      {:error, err} ->
        seal = WormChain.seal(:beam_error, %{code_hash: hash(code), error: err})
        entries = WormChain.entries()
        {:noreply,
         socket
         |> assign(:output, nil)
         |> assign(:error, err)
         |> assign(:run_seal, seal)
         |> assign(:worm_entries, entries)
         |> push_event("abzu:beam_run", %{seal: seal.id, ok: false})}
    end
  end

  def handle_event("bob_complete", _params, socket) do
    code = socket.assigns.code
    socket = assign(socket, :bob_loading, true)
    Task.async(fn ->
      case BobAgent.complete(code) do
        {:ok, {resp, verdict}} -> {:bob_done, resp, verdict}
        {:error, e} -> {:bob_done, "BOB error: #{e}", %{verdict: "SKIP", type: nil, reason: e}}
      end
    end)
    {:noreply, socket}
  end

  def handle_event("bob_explain", _params, socket) do
    code = socket.assigns.code
    socket = assign(socket, :bob_loading, true)
    Task.async(fn ->
      case BobAgent.explain(code) do
        {:ok, {resp, verdict}} -> {:bob_done, resp, verdict}
        {:error, e} -> {:bob_done, "BOB error: #{e}", %{verdict: "SKIP", type: nil, reason: e}}
      end
    end)
    {:noreply, socket}
  end

  def handle_event("bob_repair", _params, socket) do
    error = socket.assigns.error || "unknown error"
    code = socket.assigns.code
    socket = assign(socket, :bob_loading, true)
    Task.async(fn ->
      case BobAgent.repair(code, error) do
        {:ok, {resp, verdict}} -> {:bob_done, resp, verdict}
        {:error, e} -> {:bob_done, "BOB error: #{e}", %{verdict: "SKIP", type: nil, reason: e}}
      end
    end)
    {:noreply, socket}
  end

  def handle_event("set_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, String.to_atom(tab))}
  end

  def handle_info({ref, {:bob_done, text, verdict}}, socket) do
    Process.demonitor(ref, [:flush])
    seal = WormChain.seal(:bob_response, %{
      length: String.length(text),
      catcode: verdict.verdict
    })
    {:noreply,
     socket
     |> assign(:bob_response, text)
     |> assign(:bob_verdict, verdict)
     |> assign(:bob_loading, false)
     |> assign(:worm_entries, WormChain.entries())
     |> push_event("abzu:bob_complete", %{
          seal: seal.id,
          length: String.length(text),
          catcode: verdict.verdict
        })}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    {:noreply, assign(socket, :bob_loading, false)}
  end

  defp hash(str) do
    :crypto.hash(:sha256, str) |> Base.encode16(case: :lower) |> binary_part(0, 8)
  end

  def render(assigns) do
    ~H"""
    <div class="abzu-shell">
      <header class="abzu-topbar">
        <div class="abzu-logo">
          <span class="logo-abzu">ABZU</span>
          <span class="logo-dot">·</span>
          <span class="logo-sub">SOVEREIGN BEAM IDE</span>
        </div>
        <div class="abzu-status">
          <span class="status-dot alive"></span>
          <span class="status-text">BOB ONLINE</span>
          <span class="status-sep">|</span>
          <span class="status-text">CATCODE ACTIVE</span>
          <span class="status-sep">|</span>
          <span class="status-text">WORM ACTIVE</span>
          <span class="status-sep">|</span>
          <span class="status-text">OTP <%= :erlang.system_info(:otp_release) %></span>
        </div>
      </header>

      <div class="abzu-body">
        <aside class="abzu-sidebar-left">
          <div class="sidebar-section">
            <div class="sidebar-header">SOVEREIGN REGISTRY</div>
            <%= for pkg <- @registry_packages do %>
              <div class="pkg-entry">
                <span class="pkg-dot sovereign"></span>
                <span class="pkg-name"><%= pkg.name %></span>
                <span class="pkg-ver"><%= pkg.version %></span>
              </div>
            <% end %>
          </div>
          <div class="sidebar-section">
            <div class="sidebar-header">WORM CHAIN</div>
            <div class="worm-count"><%= length(@worm_entries) %> entries sealed</div>
            <%= for entry <- Enum.take(@worm_entries, 5) do %>
              <div class="worm-entry">
                <span class="worm-seal-id"><%= entry.id |> String.slice(0, 16) %></span>
                <span class="worm-action"><%= entry.action %></span>
              </div>
            <% end %>
          </div>
        </aside>

        <main class="abzu-main">
          <div class="editor-tabs">
            <button class={"tab #{if @active_tab == :editor, do: "active"}"} phx-click="set_tab" phx-value-tab="editor">ELIXIR</button>
            <button class={"tab #{if @active_tab == :registry, do: "active"}"} phx-click="set_tab" phx-value-tab="registry">PACKAGES</button>
          </div>

          <%= if @active_tab == :editor do %>
            <div class="editor-wrap" id="editor-wrap">
              <div id="monaco-editor" phx-hook="MonacoEditor" phx-update="ignore" data-code={@code} class="monaco-container"></div>
            </div>

            <div class="output-bar">
              <div class="output-controls">
                <button class="btn-run" phx-click="run">▶ RUN</button>
                <button class="btn-bob" phx-click="bob_complete" disabled={@bob_loading}>
                  <%= if @bob_loading, do: "BOB + CATCODE...", else: "⬡ BOB COMPLETE" %>
                </button>
                <button class="btn-bob-sm" phx-click="bob_explain" disabled={@bob_loading}>EXPLAIN</button>
                <%= if @error do %>
                  <button class="btn-bob-sm repair" phx-click="bob_repair" disabled={@bob_loading}>REPAIR</button>
                <% end %>
              </div>
              <%= if @run_seal do %>
                <div class="seal-badge">SEAL: <span class="seal-id"><%= @run_seal.id %></span></div>
              <% end %>
            </div>

            <div class="output-panel">
              <%= if @output do %>
                <div class="output-ok">
                  <span class="output-label">OUTPUT</span>
                  <pre><%= @output %></pre>
                </div>
              <% end %>
              <%= if @error do %>
                <div class="output-err">
                  <span class="output-label">ERROR</span>
                  <pre><%= @error %></pre>
                </div>
              <% end %>
            </div>
          <% end %>

          <%= if @active_tab == :registry do %>
            <div class="registry-panel">
              <div class="registry-header">SOVEREIGN NPM REGISTRY</div>
              <div class="registry-desc">Every package install is WORM-sealed before it hits the network.</div>
              <table class="registry-table">
                <thead><tr><th>PACKAGE</th><th>VERSION</th><th>STATUS</th><th>ORG</th></tr></thead>
                <tbody>
                  <%= for pkg <- @registry_packages do %>
                    <tr>
                      <td class="pkg-name"><%= pkg.name %></td>
                      <td><%= pkg.version %></td>
                      <td><span class="badge sovereign"><%= pkg.status %></span></td>
                      <td class="pkg-org"><%= pkg.org %></td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
        </main>

        <aside class="abzu-sidebar-bob">
          <div class="bob-header">
            <span class="bob-logo">⬡</span>
            <span class="bob-name">BOB</span>
            <span class="bob-model">IBM GAMMA → SOVEREIGN</span>
          </div>

          <div class="bob-body">
            <%= if @bob_loading do %>
              <div class="bob-thinking">
                <div class="think-dot"></div>
                <div class="think-dot"></div>
                <div class="think-dot"></div>
                BOB REASONING → CATCODE SCREENING...
              </div>
            <% end %>

            <%= if @bob_response do %>
              <%!-- CATCODE VERDICT BADGE --%>
              <%= if @bob_verdict do %>
                <div class={"catcode-badge catcode-#{String.downcase(@bob_verdict.verdict)}"}>
                  <%= case @bob_verdict.verdict do %>
                    <% "CLEAN" -> %>
                      ✓ CATCODE CLEAN — response verified
                    <% "FLAGGED" -> %>
                      ⚠ CATCODE <%= @bob_verdict.type %> — <%= @bob_verdict.reason %>
                    <% _ -> %>
                      ○ CATCODE SKIPPED
                  <% end %>
                </div>
              <% end %>
              <div class="bob-response">
                <div class="bob-response-label">BOB SAYS:</div>
                <pre class="bob-text"><%= @bob_response %></pre>
              </div>
            <% end %>

            <%= unless @bob_response || @bob_loading do %>
              <div class="bob-idle">
                <p>BOB is watching your code.</p>
                <p>Press <kbd>⬡ BOB COMPLETE</kbd> to invoke sovereign reasoning.</p>
                <p class="bob-chain-note">BOB → CATCODE Guardian → WORM seal → you.</p>
              </div>
            <% end %>
          </div>

          <div class="bob-footer">
            <span class="bob-backend">
              BACKEND: IBM GAMMA · BOB_ENDPOINT=<%= System.get_env("BOB_ENDPOINT") && "SET" || "NOT SET" %>
            </span>
            <span class="bob-backend">
              CATCODE: ACTIVE · MODEL=<%= System.get_env("CATCODE_MODEL", System.get_env("BOB_MODEL", "nemotron")) %>
            </span>
          </div>
        </aside>
      </div>
    </div>
    """
  end
end
