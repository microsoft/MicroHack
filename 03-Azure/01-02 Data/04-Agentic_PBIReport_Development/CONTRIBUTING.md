# Contributor learning guide

These are future contributor actions, **not publication authorization**.
Follow the [upstream contribution policy](../../../CONTRIBUTING.md).

1. Search proposals, then discuss a new MicroHack in an upstream proposal issue
   using its template when publication is authorized. Include public-safe scope,
   prerequisites and evidence, not private workshop documents or URLs. Confirm the
   intentional legacy folder exception to upstream lowercase/hyphen guidance.
2. Create a personal fork when requested; upstream membership/write access is not
   required. Inspect `git remote -v`. Conventionally `upstream` points to
   `microsoft/MicroHack`, `origin` to your actual fork. Do not rename shared remotes
   blindly in an app-managed worktree.
3. Fetch upstream and create a scoped topic branch in an isolated worktree. In
   app-managed sessions use the app's branch/worktree controls, not commands that
   switch the primary checkout. Keep template/reference content unchanged.
4. Review diffs, stage explicit paths and make local commits. Run the
   [local checks](tests/README.md) and preserve honest live-evidence gaps.
   Never commit credentials, account/tenant identifiers, `.pbi` caches or private
   evidence. Review staged content as carefully as the working diff.
5. **Only when explicitly requested**, push the topic branch to the personal fork
   and open a PR targeting upstream main. Use the actual fork owner/branch, explain
   scope/tests/costs/cleanup/limitations, and reference the real proposal issue.
   Draft versus ready is an author choice, not an automatic action.
6. Follow the CLA bot and code-of-conduct requirements. Inspect workflow results;
   first-time fork checks may need maintainer approval. Respond to review and push
   fixes on the same branch. Passing links does not prove a functioning Fabric lab.
7. After maintainers confirm merge, synchronize the fork, fetch both remotes and
   fast-forward a clean, unoccupied local main. Inspect divergence; do not reset
   away work. Retire the topic worktree/branch only after verifying it is merged.

Example local review commands (from the repository root):

```powershell
git status --short
git diff --check
git diff -- '03-Azure\01-02 Data\04-Agentic_PBIReport_Development'
git add -- '03-Azure\01-02 Data\04-Agentic_PBIReport_Development'
git diff --cached --stat
git diff --cached
```

A commit is local; a push publishes selected commits; a PR requests maintainer
review; only upstream merge includes the work in MicroHack. No issue, fork, push
or PR is needed to run the credential-free local authoring checks.
