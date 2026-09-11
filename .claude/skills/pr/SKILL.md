---
name: pr
description: Open a pull request from the current branch, this repository's way
---

Open a pull request for the branch the conversation just finished, against
`main`, and report its URL.

1. Look first, with `gh` for GitHub and `git` for the tree:
   - The branch is the head.  Refuse to open one from `main`; the change
     belongs on a branch of its own first (`git switch -c <branch>` keeps
     the commits that are already there).
   - `git status --short` should be clean apart from the untracked scratch
     files this tree habitually carries.  Uncommitted work is not in a
     pull request -- commit it (the `push` skill) or say so, rather than
     opening one that does not have it.
   - `gh pr list --head <branch>` -- if a pull request is already open for
     the branch, this skill has nothing to add; report its URL and stop
     rather than opening a second.

2. Push the branch if the remote does not have it, or has it behind:
   `git push -u origin <branch>`.  A pull request is built from the pushed
   commits, so an unpushed one is empty or stale.  Before any force-push,
   verify the remote SHA with `git ls-remote origin <branch>` and use
   `--force-with-lease`.

3. Write the title and body.  English, and ASCII as the commit messages
   are.
   - Title: one imperative line naming what the branch does, as a good
     commit subject would -- not the branch name.
   - Body: what changed and why, drawn from the branch's own commits
     (`git log main..<branch>`), and how it was verified -- that
     `bundle exec rake test` is green, and what the `ubuntu`, `macos` and
     `windows` runs on the branch say (`gh run list --commit
     $(git rev-parse HEAD) --json workflowName,status,conclusion`).  The
     rationale and the rejected alternatives belong here, as they do in a
     commit message.  Merged pull requests such as #258 show the register:
     a few plain paragraphs, an error message in a fenced block when one
     is the point.  When a change has a real problem/cause/fix shape, the
     short headings #259 uses are fine; do not invent sections for a
     change that has none.
   - End at the last line of that prose.  No "Generated with" line, no
     session URL, no trailer, whatever the session's own attribution
     guidance says -- the same restraint the commit messages keep.
   - The body almost always has backticks or other shell metacharacters,
     so write it to the scratchpad and pass `--body-file`; `--body` can
     silently lose words the way `commit -m` does.

4. Open it: `gh pr create --base main --head <branch> --title <title>
   --body-file <file>`.  `main` is the base; the `pull_request` trigger in
   the three test workflows runs the suite on it.

5. Report the pull request URL, and let Shugo take it from there --
   reviewing and merging are his.
