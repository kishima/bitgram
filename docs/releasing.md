# Releasing

Publishing uses the manual `release.yml` GitHub Actions workflow and RubyGems Trusted Publishing. No API key is stored in this repository.

## One-time setup

1. Confirm the gem name is available and the repository owner is correct in the gemspec and schema URL.
2. Enable MFA on the publishing RubyGems account.
3. Create the GitHub `release` environment and configure required reviewers.
4. Register a RubyGems pending trusted publisher for the repository, workflow `release.yml`, and environment `release`.

These account and repository settings are external to the source tree and must be configured by a maintainer.

## Each release

1. Ensure the Ruby/OS matrix and raster CI jobs pass on `main`.
2. Update `lib/bitgram/version.rb`, move `CHANGELOG.md` entries from Unreleased to the version and date, and refresh the bundle lockfile if tracked.
3. Run `bundle exec rake`, `bundle exec rake examples`, and `bundle exec yard doc`.
4. Run `gem build bitgram.gemspec` and inspect `gem specification bitgram-VERSION.gem files`. Install the package in a clean temporary gem directory and run `bitgram render --preset udp`.
5. Review and merge the release changes, then dispatch the Release workflow on `main` and approve its environment gate.
6. Verify installation from RubyGems and the Git tag; create GitHub release notes with `gh release create vVERSION --generate-notes`.

The historical 0.1–0.5 milestones describe implementation order; they are not automatically published by implementing the features. Format version `1` remains independent of the gem version. Use a patch release to fix a published bug; yank only for a problem such as exposed secrets, because a yanked version cannot be republished.
