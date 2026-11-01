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

## Build brief

- **Change**: `.github/workflows/review-page.yml` (triggers, plus the diff job and the publish condition); `.tool/queue.mjs` (`setup`: branch policy and dispatch; `reviewUrl`: liveness check plus dispatch, with the HTTP check kept injectable for a test); `.tool/README.md` and the workflow's header comment.
- **Run once, on GitHub**: add the `queue/*` policy, dispatch the workflow on `main`, re-sync PR #2's body (or just confirm its link now answers 200).
- **Decided unattended**: the track (plan); "latest RFC" read as PR #2's review-page link, since the RFC itself isn't approved, so it doesn't land on `main`; every row of the Decisions table above.
- **Open questions**: none blocking. If you'd rather not redeploy on every `main` push, say so, and decision 1 becomes path filter plus `setup` dispatch.
- **Cost**: the queue measures this run and writes the figures in the PR.
