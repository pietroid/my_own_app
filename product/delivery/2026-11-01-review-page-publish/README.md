# Publish the review page: GitHub Pages that actually serves the latest RFC

Track: **plan** (CI and repo settings; nothing new to draw).

## 1. The prompt

Issue [#3](https://github.com/pietroid/my_own_app/issues/3), *enable github pages and fix the publishing of latest  RFC*:

> github pages is not enabled properly

## 2. The plan

### What's wrong today (measured on 2026-11-01)

| Check | Result |
|---|---|
| `gh api repos/pietroid/my_own_app/pages` | Pages **is on**: `build_type: workflow`, `html_url: http://pietroteruya.dev/my_own_app/` (the owner's custom domain) |
| `gh run list --workflow review-page.yml` | **no run, ever** |
| `curl https://pietroteruya.dev/my_own_app/review.html` | **404** (the same for `pietroid.github.io/my_own_app/…`, which 301s there) |
| `github-pages` environment, branch policies | only `main`. **`queue/*` is missing**, though `.tool/README.md` and the workflow say it's allowed |
| PR #2 (the RFC *apps-as-data*) | its 📝 *Read it as a page* link points at that 404 |

Why it happened:

1. **Nothing was ever deployed.** `.github/workflows/review-page.yml` runs only on a push that changes `.tool/review.html` or the workflow itself. Both came in the initial commit, before `.tool/queue setup` turned Pages on, and no push has touched them since. Turning the source to "GitHub Actions" deploys nothing by itself: a workflow run does.
2. **Queue branches can't deploy.** `setup` turns Pages on but never adds `queue/*` to the `github-pages` environment, so a `queue/*` branch that changes the page would fail at `deploy-pages`.
3. **The queue links a page it never checked.** `reviewUrl` in `.tool/queue.mjs` only asks whether Pages is on, so the link goes out even when the page is a 404.

The RFC itself needs no change. The page reads PR #2's README from the GitHub API, so once `review.html` is served, the link already in PR #2 works.

### Approach

- **`.github/workflows/review-page.yml`**: deploy on **every push to `main`** (drop the path filter there; copying one static file takes about 20 s, free on a public repo). On `queue/**` it keeps deploying only when the page or the workflow changed: a first job compares the push's files (`git diff --name-only ${{ github.event.before }} ${{ github.sha }}`) and the publish job runs on `main`, or on a queue branch when that diff touches the page. It still skips cleanly when Pages is off.
- **`.tool/queue.mjs` `setup`**: after turning Pages on, (a) add the `queue/*` branch policy to `github-pages` if it's missing, and (b) run `gh workflow run review-page.yml --ref main` so the first deploy doesn't wait for a push. Running `setup` again repairs a repo that was set up before.
- **`.tool/queue.mjs` `reviewUrl`**: before linking, check that `<site>review.html` answers 200. If it doesn't, dispatch the workflow once and leave the link out of that comment, so no 404 link is sent.
- **Repair this repo during the build**: add the `queue/*` policy, dispatch the workflow on `main`, then re-sync PR #2's description, so the link that's there now works.
- **Docs**: fix the sentence in `.tool/README.md` (§ *Commenting on the page*) and the workflow's header comment, so they say what is actually done.

### References

- [Using custom workflows with GitHub Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages): the Actions source deploys through `actions/deploy-pages` in a workflow run, and the `github-pages` environment enforces the branch rules. This explains the 404: no run, no site.
- [REST: deployment branch policies](https://docs.github.com/en/rest/deployments/branch-policies): `POST /repos/{owner}/{repo}/environments/github-pages/deployment-branch-policies` with `{name: "queue/*", type: "branch"}`. The environment must have `custom_branch_policies: true` (ours does). "Wildcard characters will not match `/`", and that's fine: queue branches are `queue/<n>-<slug>`, a single segment.
- [Workflow syntax, `on.push.paths`](https://docs.github.com/en/actions/writing-workflows/workflow-syntax-for-github-actions): "If you define both `branches` and `paths`, the workflow will only run when both filters are satisfied". That's why a path filter can't be set per branch, and the queue-branch rule moves into a job condition.

### Decisions

| # | Decision | Chosen | Why |
|---|---|---|---|
| 1 | When `main` deploys | every push to `main` | It heals itself: a missed or failed deploy is fixed by the next merge. It costs about 20 s of free Actions time. The alternative (path filter plus manual dispatch) is how we got here |
| 2 | Queue branches | deploy only when they change the page | The behaviour the docs promise, so a PR that changes `review.html` is reviewed on itself without each RFC push redeploying |
| 3 | Branch policy | `setup` adds `queue/*`, idempotently | It's a repo setting, so `setup` owns it like Pages itself. No new secret |
| 4 | Link before the page is live | omitted, and the workflow dispatched | A 404 link on the phone is worse than none. The README link in the same comment still works |
| 5 | Custom domain | kept (`pietroteruya.dev/my_own_app/`, inherited from the owner's user site) | It works over https today. The queue already rewrites the `http://` that Pages reports while the certificate is in `dns_changed`. A separate domain is out of scope |
| 6 | Left out | `?md=` mode's root-relative `fetch('/…')` | It's only used locally by `.tool/doc shot`, never on Pages |

### How it will be proved

- `gh workflow run review-page.yml --ref main`, then `gh run list --workflow review-page.yml -L 1` shows **success**.
- `curl -s -o /dev/null -w '%{http_code}' https://pietroteruya.dev/my_own_app/review.html` prints **200**.
- PR #2's link (`…/review.html?repo=pietroid/my_own_app&pr=2&path=product/research/2026-11-01-apps-as-data/README.md`) renders the RFC. Proof: a `.tool/doc shot`-style screenshot in `img/`.
- `gh api repos/pietroid/my_own_app/environments/github-pages/deployment-branch-policies` lists `main` **and** `queue/*`.
- This PR's own branch (`queue/3-…`) changes the workflow, so its push deploys from a queue branch: the run shows **success**, which proves the policy.
- `node --test` on `.tool/` for `reviewUrl` (a 404 page means no link and one dispatch), and `.tool/check`.

## 3. What was built

### The contract

**The review page is linked only once it's served.** `main` deploys it on every push, so it heals itself. A `queue/*` branch deploys it only when that branch changes it. The queue never sends a link to a page that isn't answering 200.

### The files

| File | What changed |
|---|---|
| `.github/workflows/review-page.yml` | `push` on `main` and `queue/**` with no path filter. The `pages` job also works out `publish`: true on `main` and on a dispatch; on a queue branch, true only when `git diff --name-only <before> <sha>` touches `.tool/review.html` or the workflow. When the branch is new (an all-zero `before`), it diffs from the merge base with `main` instead. `publish` runs when Pages is on **and** `publish` is true |
| `.tool/queue.mjs` `reviewUrl` | Asks Pages for the site, then checks `<site>review.html` (`curl`, 10 s, following redirects). If it isn't 200, it returns `null` and dispatches `review-page.yml` on `main`, at most once every 15 minutes. The three steps (site, liveness, deploy) can be swapped out for tests |
| `.tool/queue.mjs` `pagesPolicy` (new) | Makes sure `github-pages` uses custom branch policies, then adds `main` and `queue/*` if they're missing. Returns whether `queue/*` is there afterwards. Safe to run again |
| `.tool/queue.mjs` `setup` | After Pages is on: runs `pagesPolicy`, dispatches the first deploy, and prints a ✓/✗ line for each |
| `.tool/queue.test.mjs` (new) | 6 `node:test` cases: a link on 200 (`http`→`https`), no link plus one deploy on 404, nothing asked without Pages, PR or doc, and `pagesPolicy` in three starting states |
| `.tool/check` | A `tool-test` step (`node --test .tool/*.test.mjs`) runs when anything under `.tool/` changes |
| `.tool/README.md` | § *Commenting on the page* now says what is actually done. § `check` names the new step |

### The proof, run

```
$ node --test .tool/queue.test.mjs
✔ reviewUrl links the page when it answers 200, on https
✔ reviewUrl leaves a 404 page out and dispatches the deploy once
✔ reviewUrl without Pages, a PR or a doc asks nothing more
✔ pagesPolicy adds queue/* when only main is allowed
✔ pagesPolicy writes nothing when queue/* is there
✔ pagesPolicy turns custom policies on, then adds main and queue/*
ℹ tests 6  pass 6  fail 0

$ .tool/check
✓ tool-test (1s)
```

The real `reviewUrl` run against this repo today, with only the dispatch stubbed out. Pages is on, the page is still 404, so no link is made:

```
$ curl -s -o /dev/null -w '%{http_code}' https://pietroteruya.dev/my_own_app/review.html
404
$ node -e "…reviewUrl({repo:'pietroid/my_own_app'},{pr:2,doc:'…apps-as-data/README.md'},{deploy:stub})"
(would dispatch review-page.yml)
null
```

The workflow's `publish` decision, run in a scratch repo with the step's own script:

```
main: publish=true
queue, page changed: publish=true
queue, new branch: publish=true
queue, no change: publish=false
```

### Where the build differs from the plan

- **The one-time repair on GitHub was not run.** The plan had this run add `queue/*` to the `github-pages` environment, dispatch the deploy on `main`, and re-sync PR #2. The sandbox's permission check refused those writes to the shared repo, and I didn't work around it. So today the environment still allows only `main`, and the page is still a 404. Section 4 has the two commands. Without them, the page goes live on the first push to `main` after this PR merges, since `main` now always deploys.
- **This PR's own deploy run will fail.** Its branch changes the workflow, so the queue's push asks for a deploy from `queue/3-…`, and the environment refuses that until `queue/*` is added. It's the bug this PR fixes, not a new one, and it doesn't block the merge (the workflow isn't a required check). Once `queue/*` is added, re-running that run proves the policy, which is the plan's last proof.
- **Added:** the `.tool/check` step. The plan named `node --test`, but nothing ran `.tool/` tests, so it now runs whenever `.tool/` changes.
- No `product/spec/` file. This is internal tooling, and its spec is `.tool/README.md`, which was updated.

### Decided unattended

- Every row of the Decisions table in section 2, as approved.
- The repair commands are left to you (see above) rather than run another way.
- At most one deploy dispatch every 15 minutes from a running queue. A gate calls `reviewUrl` twice (the PR body and the comment), and a run takes about a minute.

## 4. How to turn it on

Run once, from the main checkout, after this merges (or before, to see this PR's run go green):

```bash
.tool/queue setup     # adds queue/* to github-pages, dispatches the deploy on main
# or by hand:
gh api -X POST repos/pietroid/my_own_app/environments/github-pages/deployment-branch-policies -f name='queue/*' -f type=branch
gh workflow run review-page.yml --ref main
```

Then `gh run list --workflow review-page.yml -L 1` shows success, and `curl -s -o /dev/null -w '%{http_code}' https://pietroteruya.dev/my_own_app/review.html` prints 200. PR #2's link already points there, so it starts working without an edit. The next gate the queue reaches writes the link into the PR body again either way.

Without the commands: the merge itself deploys `main`, and the page comes up. Until `queue/*` is added, only a queue branch that changes the page can't deploy it. Nothing needs a new secret or env var.

## 5. Cost and time

Measured by the queue: see the pull request. There was no spend outside Claude: Actions minutes on a public repo are free.
