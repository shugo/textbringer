---
name: sync
description: Switch to main, pull, and delete the work branch once its pull request is merged
---

Bring the tree back to an up-to-date `main` after a pull request has been
merged, and clean up the branch it came from.  Nothing here is
destructive as long as every step looks first; a branch is deleted only
after GitHub says its pull request is merged.

1. Look first:
   - `git branch --show-current` -- remember it; if it is not `main`, it
     is the branch to clean up in step 3.
   - `git status --short` shows no tracked change.  A change lying in the
     tree would follow the switch onto `main`, or block it; commit it
     (the `push` skill) or say so and stop.  The untracked scratch files
     this tree habitually carries are fine to leave.

2. Switch and pull, fast-forward only:

       git switch main
       git pull --ff-only

   `main` is never edited locally here, so a pull that cannot
   fast-forward means something is wrong; stop and report rather than
   merging or rebasing.  Note the range `git pull` prints (`old..new`)
   and read `git log --oneline old..new` -- the report names what came
   down, usually the merge of the pull request just finished plus any
   Dependabot merges that landed meanwhile.

3. Delete the work branch, once it is known to be merged.  Ask GitHub,
   not `git branch --merged`, since a merged pull request is the fact
   that matters:

       gh pr list --head <branch> --state merged --json number,url --jq '.[0] | "\(.number) \(.url)"'

   An empty answer means no merged pull request for the branch; leave it
   alone and say so -- it may be open, or never have had one.  When there
   is a merged pull request:

       git branch -d <branch>
       git push origin --delete <branch>

   Pull requests here are merged with a merge commit, so `-d` accepts
   the branch; if `-d` refuses, the branch has commits the merge did not
   carry -- report that instead of reaching for `-D`.  Check the remote
   side first with `git ls-remote --heads origin <branch>`; GitHub may
   already have deleted it, which is not an error.  Finish with
   `git fetch --prune` so the stale remote-tracking ref goes too.

   Only the branch the tree was on is deleted.  Other local or remote
   branches (`feature/*`, old experiments) are not this skill's
   business, even when their pull requests are merged, unless they are
   named explicitly.

4. Report: the branch that was left, the pulled range with the merge it
   carries, and which of the local and remote branches were deleted.
