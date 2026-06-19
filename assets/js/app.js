// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/abzu_ide"
import topbar from "../vendor/topbar"
import MonacoEditor from "./monaco_hook"

// Load Monaco require from CDN
if (!window.require) {
  const script = document.createElement('script');
  script.src = 'https://cdn.jsdelivr.net/npm/monaco-editor@0.52.0/min/vs/loader.js';
  script.onload = () => window._monacoReady = true;
  document.head.appendChild(script);
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, MonacoEditor},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// ── Novus.ai (Pendo) event tracking ─────────────────────────────
// Fires pendo.track() for key ABZU actions so the Novus dashboard
// shows real usage data from the hackathon demo session.
function novusTrack(event, props) {
  if (window.pendo && typeof window.pendo.track === 'function') {
    window.pendo.track(event, props || {})
  }
}

// Page loaded = IDE opened
window.addEventListener('phx:page-loading-stop', () => {
  novusTrack('abzu_ide_load', { ts: Date.now() })
})

// Server pushes these events via Phoenix.LiveView.push_event/3
window.addEventListener('phx:abzu:beam_run',    e => novusTrack('abzu_beam_run',    e.detail || {}))
window.addEventListener('phx:abzu:bob_complete', e => novusTrack('abzu_bob_complete', e.detail || {}))
window.addEventListener('phx:abzu:bob_repair',   e => novusTrack('abzu_bob_repair',   e.detail || {}))
window.addEventListener('phx:abzu:pkg_install',  e => novusTrack('abzu_pkg_install',  e.detail || {}))
window.addEventListener('phx:abzu:worm_seal',    e => novusTrack('abzu_worm_seal',    e.detail || {}))

// Button-level click capture (backup path — works even without server push)
document.addEventListener('click', e => {
  const btn = e.target.closest('button[phx-click]')
  if (!btn) return
  const action = btn.getAttribute('phx-click')
  const trackMap = {
    'run':         'abzu_beam_run',
    'bob_complete':'abzu_bob_complete',
    'bob_explain': 'abzu_bob_explain',
    'bob_repair':  'abzu_bob_repair',
  }
  if (trackMap[action]) novusTrack(trackMap[action], { ts: Date.now() })
})

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

