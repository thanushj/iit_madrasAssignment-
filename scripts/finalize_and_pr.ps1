param(
  [switch]$AutoMerge
)

# finalize_and_pr.ps1
# - runs tests & formatting inside docker-compose api
# - fixes with ruff, formats with black
# - commits & pushes current branch
# - creates a PR using gh if installed
# - optionally sets PRIVATE_KEY secret from keys\private.pem if present

$ErrorActionPreference = "Stop"

function RunCmd($cmd) {
  Write-Host ">>> $cmd"
  $proc = Start-Process -FilePath "powershell" -ArgumentList "-NoProfile","-Command",$cmd -NoNewWindow -Wait -PassThru
  if ($proc.ExitCode -ne 0) { throw "Command failed with exit code $($proc.ExitCode): $cmd" }
}

Write-Host "Starting finalization automation..."

try {
  Write-Host "`n==> Running ruff fix, black, pytest inside docker-compose api"
  RunCmd "docker compose exec -e PYTHONPATH=/app api ruff check --fix ."
  RunCmd "docker compose exec -e PYTHONPATH=/app api black ."
  RunCmd "docker compose exec -e PYTHONPATH=/app api pytest -q --maxfail=1"
} catch {
  Write-Host "One of the checks failed: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}

# Git commit & push
Write-Host "`n==> Git add/commit/push"
$branch = (git rev-parse --abbrev-ref HEAD).Trim()
if (-not $branch) { Write-Host "Cannot determine branch"; exit 1 }

# Stage changes
git add -A

$changes = (git status --porcelain).Trim()
if ($changes) {
  git commit -m "chore: finalize formatting and tests"
} else {
  Write-Host "No changes to commit."
}

git push -u origin $branch

# PR content
$prTitle = "chore: finalize infra + full implementation"
$prBody = @"
Summary:
- Adds RS256 auth (access + refresh rotation), Redis blacklist, Project/Issue/Comment models and endpoints, Alembic migrations, Docker + docker-compose, k8s templates, CI skeleton and tests.

Checklist:
- [x] Containers build and run
- [x] Alembic migrations applied / stamped
- [x] Seed data created
- [x] Tests passing (`pytest`)
- [x] Lint/format checks passing (`ruff`, `black`)
- [ ] GitHub Actions CI passing
- [ ] Add `PRIVATE_KEY` secret in repo settings
- [ ] Merge and tag release
"@

# Create PR with gh if available
$gh = Get-Command gh -ErrorAction SilentlyContinue
if ($gh) {
  Write-Host "`n==> Creating PR with gh"
  try {
    gh pr create --title $prTitle --body $prBody --base main --head $branch --repo thanushj/iit_madrasAssignment-
  } catch {
    Write-Host "gh failed to create PR: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "Please create the PR manually and paste the body above."
  }

  # set secret if keys/private.pem exists
  $priv = Join-Path $PSScriptRoot "..\keys\private.pem"
  if (Test-Path $priv) {
    try {
      $content = Get-Content -Raw $priv
      gh secret set PRIVATE_KEY --body $content --repo thanushj/iit_madrasAssignment-
      Write-Host "PRIVATE_KEY secret set."
    } catch {
      Write-Host "Failed to set PRIVATE_KEY via gh: $($_.Exception.Message)" -ForegroundColor Yellow
      Write-Host "Set the secret manually in the repo Settings -> Secrets -> Actions."
    }
  } else {
    Write-Host "No keys/private.pem found; skipping secret creation."
  }

  if ($AutoMerge) {
    try {
      $num = gh pr view --json number --jq .number --repo thanushj/iit_madrasAssignment-
      if ($num) { gh pr merge $num --merge --repo thanushj/iit_madrasAssignment- }
    } catch {
      Write-Host "Auto-merge failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
  }
} else {
  Write-Host "`n==> GitHub CLI (gh) not found. Manual steps:"
  Write-Host "- Create a PR from branch $branch -> main with the following title and body."
  Write-Host "Title:`n$prTitle`n`nBody:`n$prBody"
  if (Test-Path (Join-Path $PSScriptRoot "..\keys\private.pem")) {
    Write-Host "- Add the PRIVATE_KEY secret in GitHub repository Settings -> Secrets -> Actions with the contents of keys/private.pem."
  }
}

Write-Host "`nAutomation finished. Inspect PR / CI on GitHub to merge."