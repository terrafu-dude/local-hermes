/* Web-dashboard plugin: a "Services" tab linking the local stack.
   Plain IIFE — no build step. Loads via dashboard/manifest.json. */
(function () {
  "use strict";
  var SDK = window.__HERMES_PLUGIN_SDK__;
  var React = SDK.React;
  var Card = SDK.components.Card, CardHeader = SDK.components.CardHeader,
      CardTitle = SDK.components.CardTitle, CardContent = SDK.components.CardContent;
  var h = React.createElement;

  var SERVICES = [
    { label: "ComfyUI",     url: "http://localhost:8188", desc: "FLUX.1-schnell image generation" },
    { label: "Ollama WebUI",url: "http://localhost:3000", desc: "Chat with the local LLM (qwen3.8-27b)" },
    { label: "Hermes",      url: "http://localhost:9120", desc: "This dashboard" },
    { label: "Piper TTS",   url: "http://localhost:5000", desc: "Local neural speech" }
  ];

  function Services() {
    return h(Card, null,
      h(CardHeader, null, h(CardTitle, null, "Local services")),
      h(CardContent, null,
        h("div", { className: "grid grid-cols-1 sm:grid-cols-2 gap-4" },
          SERVICES.map(function (s) {
            return h(Card, { key: s.url },
              h(CardHeader, null,
                h("a", { href: s.url, target: "_blank", rel: "noopener nopener" },
                  h("div", { className: "font-semibold" }, s.label),
                  h("div", { className: "text-sm text-muted-foreground mt-1" }, s.url),
                  h("div", { className: "text-sm text-muted-foreground mt-2" }, s.desc)
                )
              )
            );
          })
        )
      )
    );
  }

  window.__HERMES_PLUGINS__.register("services", Services);
})();
