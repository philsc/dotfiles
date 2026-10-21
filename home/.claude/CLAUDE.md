# Git and GitHub PRs

- Never create local branches for PRs (no `git checkout -b`, `git switch -c`,
  `git branch <name>`).
- Work on a detached HEAD instead, starting from the up-to-date base:
  `git fetch origin && git checkout --detach origin/main` (or whichever base branch is right).
- Push the commits to a named branch on the remote (e.g. GitHub) without creating it locally:
  `git push origin HEAD:refs/heads/dev/<user>/<short-name>`
  (`<user>` is `$USER`).
- Open the PR with `gh pr create --head <user>/<short-name> --base main ...`.
- For follow-up changes, commit on the same detached HEAD and push again with
  `git push origin HEAD:<user>/<new-short-name>`.
- To work on an existing PR, check it out detached:
  `git fetch origin <branch> && git checkout --detach FETCH_HEAD`
  (not `gh pr checkout`, which creates a local branch).
