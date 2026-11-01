# Product

Everything written about My Own App that is not code. The rules of the
product as they stand are in [AGENTS.md](../AGENTS.md).

| Folder | What is in it | Written by |
|--------|---------------|------------|
| [`spec/`](./spec) | Feature specs kept out of `AGENTS.md` so they cost context only when a task touches them | `/create`, by hand |
| [`research/`](./research) | One folder per topic (`YYYY-MM-DD-<slug>/`): the RFC as `README.md`, with the `data/`, `code/`, `reports/` and `notes/` behind it; `concepts.md`, the ideas every RFC taught | `/research` |
| [`improvements/`](./improvements) | One folder per improvement to how we work (docs, skills, `.tool/`, harness, cost): what changed, the evidence, references | `/improve` |
| [`delivery/`](./delivery) | One folder per delivered feature (`YYYY-MM-DD-<slug>/README.md`): the prompt, the approved design, what was built, its cost | `/create` |

To read or comment on any of them: `.tool/doc ls`, `.tool/doc open <words>`
(see [.tool/README.md](../.tool/README.md)).
