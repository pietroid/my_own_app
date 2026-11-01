# Concepts: what the RFCs taught

Every idea an RFC taught (*Ideas to keep*, the `[!TIP]`s recapped in *Go
deeper*): the sentence to remember, the source to read, and where it was
met. A new RFC reads this first, gives an idea already here one line and a
link, and goes one level deeper on it (see `/research`, Phase 3). Newest
topics add to the bottom of their group.

RFCs: [2026-11-01-apps-as-data](2026-11-01-apps-as-data/README.md).

## Generated apps

- **Screen, data and behaviour are three stored artefacts.** A2UI keeps the
  screen (`updateComponents`) apart from its values (`updateDataModel`,
  joined by JSON Pointer paths); behaviour is a third thing, named by the
  screen and kept by the server. [A2UI v0.9](https://a2ui.org/specification/v0.9-a2ui/).
  Met in: [apps-as-data](2026-11-01-apps-as-data/README.md).
- **Build once, run many.** A generated UI costs "a minute or two" per page;
  stored, it costs nothing to open again and is the same every time.
  [Leviathan et al. 2026](https://arxiv.org/html/2604.09577v1).
  Met in: [apps-as-data](2026-11-01-apps-as-data/README.md).

## Running agent-written code

- **A function declares its input.** "The function input is a JSON object
  which is the result of a GraphQL input query you define": the runner hands
  over only that, so the cost stays flat as the data grows (0.3 ms vs 58 ms at
  4.4 MB). [Shopify Functions](https://shopify.dev/docs/api/functions/current).
  Met in: [apps-as-data](2026-11-01-apps-as-data/README.md).
- **Agent-written code is untrusted code.** "The `node:vm` module is not a
  security mechanism"; use a separate isolate (isolated-vm) or an
  interpreter in WASM (QuickJS), with memory and time limits.
  [Node vm](https://nodejs.org/api/vm.html).
  Met in: [apps-as-data](2026-11-01-apps-as-data/README.md).
