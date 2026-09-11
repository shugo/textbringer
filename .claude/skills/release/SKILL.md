---
name: release
description: Cut a release -- check main, run rake bump, watch the gem go out
---

Release what is on `main`: bump the version, tag it, push, and report when
RubyGems.org has it.  A release cannot be taken back, so every step looks
before it acts.

The mechanism is `bundle exec rake bump` (the task in the Rakefile)
followed by `.github/workflows/push_gem.yml`, which the tag triggers, as
the README's development section describes.  Do not use `bundle exec rake
release`: it pushes the gem from the local machine, which has no
RubyGems.org credentials here, and the tag it pushes first triggers the
workflow, which publishes the same gem through trusted publishing -- two
publishes of one version, one of which fails.

1. Look first.  Every one of these has to hold, and the skill stops and
   says which does not rather than releasing around it:
   - `git branch --show-current` is `main`.  Releases are cut from there;
     `rake bump` checks `main` out itself, but a switch mid-release is a
     surprise, not a step.
   - `git status --short` shows no tracked change.  `rake bump` commits
     with `-a`, so any tracked change lying in the tree would go into the
     version commit; commit it (the `push` skill) or set it aside.  The
     untracked scratch files this tree habitually carries are harmless to
     `-a` and can stay.
   - `git fetch origin` and then `git rev-parse HEAD origin/main` agree.
     `rake bump` pulls, so a remote ahead of HEAD (a Dependabot merge is
     the usual case) would be released without having been looked at.
   - CI is green for HEAD on all three test workflows:

         gh run list --commit $(git rev-parse HEAD) --json workflowName,status,conclusion --jq '.[] | "\(.workflowName): \(.status) \(.conclusion)"'

     says `completed success` for `ubuntu`, `macos` and `windows`.
     Queued or running is not green yet -- start one background wait on
     their conclusion, as the `push` skill does, and take the release up
     when it lands.  Red is a stop.

2. Know what is being released.  The version is a single integer
   (`VERSION = "27"`) and `rake bump` adds one, so the next version is the
   last tag plus one:

       git describe --tags --abbrev=0
       git log --oneline $(git describe --tags --abbrev=0)..HEAD

   Read the subjects, and the bodies where a subject leaves it open, and
   name in the report the commits the release carries.  When the history
   since the last tag is only documentation, Dependabot bumps and
   housekeeping, ask whether a release is wanted at all rather than
   cutting one for nothing.

3. Bump, tag and push, which one command does:

       bundle exec rake bump

   It checks out `main`, pulls, rewrites `lib/textbringer/version.rb`,
   commits that one file with the subject `Bump version to <N>` -- the way
   every release commit here reads, with no trailer -- pushes, tags the
   commit `v<N>`, and pushes the tag.  Check its work: `git show --stat
   HEAD` names version.rb alone, `git tag --points-at HEAD` names the tag,
   and `git ls-remote --tags origin v<N>` shows it on the remote.  If the
   task stopped partway, report exactly which of those steps happened and
   do not repeat it blindly: a pushed tag is already a release.  Never
   force-push here: a tag that reached the remote is what the workflow
   released, and rewriting it would release something else under the same
   name.

4. Watch the gem go out.  The `v*` tag runs `push_gem.yml`, which
   publishes through RubyGems.org's trusted publishing, creates a GitHub
   release with generated notes, and purges the README's image cache.
   Check once -- `gh run list --workflow push_gem.yml --limit 1` -- and
   start one background wait on that run's conclusion:

       RUN=$(gh run list --workflow push_gem.yml --limit 1 --json databaseId --jq '.[0].databaseId')
       until gh run view $RUN --json status --jq .status | grep -q completed; do sleep 20; done
       gh run view $RUN --json conclusion --jq .conclusion

   Never poll in the foreground.  When it is green, confirm the version
   is up with `gem search -r -e textbringer`.  A red run means the tag is
   on the remote and the gem may not be on RubyGems.org; report the
   failed step's log (`gh run view $RUN --log-failed`), and leave the tag
   where it is -- the fix is a new release, not a moved tag.

5. Report: the version, the range the release covers
   (`v<previous>..v<new>`) with the commits that decided it, the
   workflow's conclusion once it arrives with
   https://rubygems.org/gems/textbringer, and the GitHub release
   (`gh release view v<N> --json url --jq .url`).  Nothing else needs
   updating for a release: neither README carries a version number, and
   the gemspec reads it from version.rb.
