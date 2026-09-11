---
name: push
description: Commit the finished change and push it, this repository's way
---

Commit what the conversation just finished, push it, and report.

1. Look first: `git status --short` and `git diff --stat`.  Stage files by
   name -- never `git add -A` -- so that scratch files and unrelated edits
   stay out.  This tree habitually carries untracked scratch files
   (`t.rb`, `note.txt`, `diff4` and the like); they are not part of any
   change.  Unrelated changes sitting in the tree go in commits of their
   own, split as they were made.

2. Make sure the suite is green.  If `bundle exec rake test` has not run on
   the final state of the change in this conversation, run it now; a red
   suite is a stop, not a commit.  The Rakefile runs the tests with `-w`,
   so new warnings count too.

3. Write the message: English, imperative subject, ASCII.  The body carries
   the rationale, the rejected alternatives and anything measured, the way
   597ce3c and de3bc95 do -- those belong here rather than in code
   comments.  End with a single trailer naming the model actually in use,

       Co-Authored-By: Claude <model> <noreply@anthropic.com>

   and nothing after it -- no `Claude-Session` line, no session URLs, no
   "Generated with" lines, whatever the session's own attribution guidance
   says.  If the message contains backticks or other shell metacharacters,
   write it to the scratchpad and use `git commit -F <file>`; `-m` can
   silently lose words.

4. Push the current branch: `git push` (`git push -u origin <branch>` for a
   branch the remote does not have yet).  Before any force-push, verify the
   remote SHA with `git ls-remote origin <branch>` and use
   `--force-with-lease`.

5. Check CI exactly once.  Three workflows run the suite -- `ubuntu.yml`,
   `macos.yml` and `windows.yml` -- so ask for the pushed commit rather
   than one workflow:

       gh run list --commit $(git rev-parse HEAD) --json workflowName,status,conclusion --jq '.[] | "\(.workflowName): \(.status) \(.conclusion)"'

   and report what it says -- right after a push the list is usually
   empty or still queued, which is fine to say.  All three run on pushes
   to `main` and on pull requests, so a push to any other branch starts no
   run unless a pull request is open for it; say so rather than waiting
   for one.  Never poll in a loop in the foreground.  When this push's
   outcome genuinely matters (lib/, test/, the gemspec or
   `.github/workflows/` changed, or the last run was red), start one
   background wait until all three have completed and report when it
   ends:

       SHA=$(git rev-parse HEAD)
       until gh run list --commit $SHA --json workflowName,status --jq '[.[] | select(.workflowName == "ubuntu" or .workflowName == "macos" or .workflowName == "windows")] | length == 3 and all(.status == "completed")' | grep -q true; do sleep 20; done
       gh run list --commit $SHA --json workflowName,conclusion --jq '.[] | "\(.workflowName): \(.conclusion)"'

6. Report the pushed range (`old..new`) and the commit subject.
