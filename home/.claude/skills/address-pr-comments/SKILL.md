---
name: address-pr-comments
description: "Address the open review comments on the current pull request and every PR stacked with it. Evaluates each comment, fixes the ones worth fixing, pushes all PRs in one go, then replies to every comment with the decision, reasoning and action, and resolves the threads. Use when asked to address, handle, work through or respond to PR comments, review feedback or reviewer requests on a PR or a stack of PRs. Optional argument: a PR number (defaults to the current PR)."
---

# Address PR comments across a stack

Work through the open comments of the current PR and of every PR in its stack, in this order:
find the stack, collect the comments, evaluate them, fix what is worth fixing, push all PRs at
once, then reply and resolve. Running this skill authorizes the push and the replies; don't ask
for a further confirmation before either.

`$ARGUMENTS`, if given, is the PR number to start from. Otherwise start from the current PR.

## 1. Find the PR and its stack

Record each PR's number, head branch, base branch and head SHA **now**. These head SHAs are the
lease for the push in step 5.

### In a Grenadine session

If the grenadine MCP tools (`session_pr`, `manage_prs`, `update_prs`) are available, you're in a
Grenadine session. Never `git push` or open PRs any other way there.

- Call `session_pr`. It gives the session's PR, its stack and the PRs the session manages.
- Scope is the **linear chain** through the starting PR: every open PR below it down to the base
  branch and every open PR above it. If the stack forks above some PR, follow the fork that contains
  the starting PR; if the fork is above the starting PR, follow the fork the session already
  manages, or ask the user which one when that's unclear.
- PRs on other forks are out of scope: don't change or reply on them. Still collect their open
  comments (step 2) so you can list them in the final summary.
- Take over every PR in the chain the session doesn't manage yet with `manage_prs`, and bring
  their commits onto HEAD as its result describes.

### Elsewhere

- Find the starting PR: `gh pr view $ARGUMENTS --json number,headRefName,baseRefName,headRefOid`
  (without an argument, `gh pr view` uses the current branch; on a detached HEAD, find the PR whose
  `headRefOid` is `git rev-parse HEAD` via `gh pr list --state open --json ...`).
- Collect **every open PR connected to it**, forks included: list the open PRs once with
  `gh pr list --state open --limit 200 --json number,headRefName,baseRefName,headRefOid`, then
  walk down (the PR whose `headRefName` is this PR's `baseRefName`) until you reach a branch that
  is no PR's head, and walk up (every PR whose `baseRefName` is a collected PR's `headRefName`)
  until nothing new turns up.
- Fetch every PR's head (`git fetch origin <branch>`) and work on a detached HEAD; don't create
  local branches.

## 2. Collect the open comments

For every PR in scope, fetch these with `gh api graphql` (paginate with `after` if `hasNextPage`):

```graphql
query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      reviewThreads(first: 100) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id isResolved isOutdated path line
          comments(first: 50) { nodes { author { login } body createdAt url diffHunk } }
        }
      }
      reviews(last: 100) { nodes { author { login } state body createdAt url } }
      comments(last: 100) { nodes { author { login } body createdAt url } }
    }
  }
}
```

A comment is **open** when it is one of:

- **Inline thread:** a review thread with `isResolved: false`, from anyone, bots included.
  Outdated threads count too; check whether the current code still has the problem.
- **Top-level:** a review summary (`reviews[].body`) or conversation comment (`comments`) with real
  content, posted after the latest conversation comment containing the marker
  `<!-- address-pr-comments -->` on that PR (all of them if there is no marker yet). Skip the
  marked comments themselves and content-free noise: empty review bodies, bare approvals, and
  status posts from CI, coverage, deploy-preview and similar bots.

If no PR in scope has open comments, say so and stop.

## 3. Evaluate every open comment

Read each comment against the code it's about, the PR's purpose, and the repo's instructions
(AGENTS.md, CLAUDE.md, contributing docs). Decide one of:

- **Address:** it's correct and makes the change better, in proportion to its cost.
- **Decline:** it's wrong, conflicts with the repo's conventions or with something the user
  decided, or costs more than it's worth. Have a concrete reason, not a preference.
- **Already done:** the current code already handles it (e.g. an outdated thread fixed earlier).

Stop and ask the user (with your recommendation) instead of deciding when:

- the comment is ambiguous, or you'd be guessing what the reviewer wants;
- it's a design or product decision that belongs to the user;
- it's valid but **out of scope** for the stack (e.g. "this whole module should be refactored").
  Always ask about these, one comment at a time, before acting.

Batch the questions so the user can answer them together where they're independent. Otherwise
decide on your own.

## 4. Address the comments

- Work bottom-up through the stack. For each PR with comments to address, make **one new commit**
  on top of that PR's existing commits (e.g. "Address review comments", following the repo's
  commit-message conventions and attribution rules). Don't fold fixes into earlier commits.
- Rebase the PRs above onto the new commit, so each PR keeps its own commits followed by its
  new one. Resolve conflicts rather than dropping changes.
- Build, test, lint and format exactly as the repo's instructions say (e.g. AGENTS.md), and fold
  formatter changes into the new commits. Don't push anything with failing checks; fix them, or
  stop and report if you can't.
- Keep notes per comment of what changed and in which commit; the replies need them.

## 5. Update all PRs in one go

- **Grenadine:** one `update_prs` call with one `prs` entry per PR in the chain, bottom first,
  each naming its `pr` and its new tip `commit` (unchanged PRs keep their current tip).
- **Elsewhere:** one atomic push of every changed branch, leased on the heads recorded in step 1:

  ```sh
  git push --atomic origin \
    --force-with-lease=<branch1>:<sha1-at-start> <tip1>:refs/heads/<branch1> \
    --force-with-lease=<branch2>:<sha2-at-start> <tip2>:refs/heads/<branch2>
  ```

If the push is refused because a branch moved since step 1, someone else pushed. Stop: don't
overwrite their work, don't post any replies, and tell the user what moved.

## 6. Reply to every evaluated comment, then resolve

Only after the push succeeded. Every comment evaluated in step 3 gets an answer stating the
**decision**, the **reasoning**, and the **action** (with the short SHA of the commit that made
the change, or why nothing changed). Keep replies short and specific.

- **Inline threads:** reply in the thread, then resolve it, declined ones included:

  ```sh
  gh api graphql -f query='mutation($id: ID!, $body: String!) {
    addPullRequestReviewThreadReply(input: {pullRequestReviewThreadId: $id, body: $body}) { clientMutationId }
  }' -f id=<thread id> -f body=<reply>
  gh api graphql -f query='mutation($id: ID!) {
    resolveReviewThread(input: {threadId: $id}) { clientMutationId }
  }' -f id=<thread id>
  ```

- **Top-level comments:** they can't be resolved. Post **one** conversation comment per PR
  (`gh pr comment <n> --body-file -`) that answers each one in turn, linking or quoting it, and
  ends with the line `<!-- address-pr-comments -->` so the next run knows where to start.

In a Grenadine session, don't reply on PRs outside the chain.

## 7. Report to the user

Summarize per PR in a table: comment (short, linked), decision, reasoning, action/commit. Then
list anything left over: questions the user deferred, checks that failed, and (in a Grenadine
session) PRs on other forks of the stack that still have open comments.
