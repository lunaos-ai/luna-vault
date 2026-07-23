# Homebrew tap publish

## Formula path (this repo)

`dist/homebrew/vibevault.rb`

## Publish to `finsavvyai/homebrew-tap`

```bash
gh repo clone finsavvyai/homebrew-tap /tmp/homebrew-tap
cp dist/homebrew/vibevault.rb /tmp/homebrew-tap/Formula/vibevault.rb
cd /tmp/homebrew-tap
git checkout -b vibevault-0.1.0
git add Formula/vibevault.rb
git commit -m "vibevault 0.1.0"
git push -u origin HEAD
gh pr create --title "vibevault 0.1.0" --body "Local-first secret manager CLI for AI coding workflows."
```

## Local test

```bash
brew install --build-from-source --formula ./dist/homebrew/vibevault.rb
vibevault --version
```
