param(
    [switch]$Staged,
    [switch]$History
)

$ErrorActionPreference = "Stop"

$ForbiddenExtensions = @(".jks", ".keystore", ".p12", ".pem", ".key")
$ForbiddenNames = @(
    "google-services.json",
    ".env"
)

$Patterns = @(
    @{ Name = "Private Key Header"; Regex = "-----BEGIN ([A-Z0-9 ]+ )?PRIVATE KEY-----" },
    @{ Name = "Firebase / GCP Service Account"; Regex = '"type"\s*:\s*"service_account"' },
    @{ Name = "GitHub Token"; Regex = '\b(ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{20,})\b' },
    @{ Name = "AWS Access Key"; Regex = '\bAKIA[0-9A-Z]{16}\b' },
    @{ Name = "Slack Token"; Regex = '\bxox[baprs]-[0-9A-Za-z-]{10,}\b' },
    @{ Name = "Hardcoded DeepSky Admin Secret"; Regex = '(?i)DEEPSKY_ADMIN_SECRET\s*[:=]\s*["'']?(?!change-me|placeholder|example|\$\{)[A-Za-z0-9_\-+/=]{12,}' }
)

function Test-ForbiddenFileName([string]$Path) {
    $norm = $Path.Replace("\", "/")
    $name = [System.IO.Path]::GetFileName($norm)
    $ext = [System.IO.Path]::GetExtension($norm).ToLowerInvariant()

    if ($ForbiddenExtensions -contains $ext) {
        return "Forbidden key/certificate extension '$ext'"
    }
    if ($ForbiddenNames -contains $name) {
        return "Forbidden file name '$name'"
    }
    if ($name -like ".env.*" -and $name -ne ".env.example") {
        return "Forbidden environment file '$name'"
    }
    if ($name -like "firebase-service-account*.json") {
        return "Forbidden Firebase service account file '$name'"
    }
    return $null
}

$violations = [System.Collections.Generic.List[string]]::new()

if ($History) {
    if (Get-Command gitleaks -ErrorAction SilentlyContinue) {
        & gitleaks detect --config ".gitleaks.toml" --redact --verbose
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }

    $commits = git rev-list --all
    foreach ($commit in $commits) {
        $files = git diff-tree --no-commit-id --name-only -r $commit
        foreach ($file in $files) {
            $reason = Test-ForbiddenFileName $file
            if ($reason) {
                $violations.Add("[$commit] $file : $reason")
            }
        }
        $patch = git show $commit --pretty=format:
        foreach ($p in $Patterns) {
            foreach ($line in ($patch -split "`n")) {
                if ($line.StartsWith("+") -and -not $line.StartsWith("+++") -and ($line -match $p.Regex)) {
                    $violations.Add("[$commit] matched $($p.Name)")
                }
            }
        }
    }
}
elseif ($Staged) {
    $files = git diff --cached --name-only --diff-filter=ACM
    foreach ($file in $files) {
        if ([string]::IsNullOrWhiteSpace($file)) { continue }
        $reason = Test-ForbiddenFileName $file
        if ($reason) {
            $violations.Add("$file : $reason")
            continue
        }
        $content = git show ":$file" 2>$null
        if ($LASTEXITCODE -ne 0 -or $null -eq $content) { continue }
        $text = ($content -join "`n")
        foreach ($p in $Patterns) {
            if ($text -match $p.Regex) {
                $violations.Add("$file : matched $($p.Name)")
            }
        }
    }
}
else {
    $files = git ls-files
    foreach ($file in $files) {
        if ([string]::IsNullOrWhiteSpace($file)) { continue }
        $reason = Test-ForbiddenFileName $file
        if ($reason) {
            $violations.Add("$file : $reason")
            continue
        }
        if (Test-Path $file -PathType Leaf) {
            $text = Get-Content -Raw -Path $file -ErrorAction SilentlyContinue
            if ($null -eq $text) { continue }
            foreach ($p in $Patterns) {
                if ($text -match $p.Regex) {
                    $violations.Add("$file : matched $($p.Name)")
                }
            }
        }
    }
}

if ($violations.Count -gt 0) {
    Write-Error ("Secret scan failed:`n - " + ($violations -join "`n - "))
    exit 1
}

Write-Host "Secret scan passed: no forbidden files or secret patterns found."
exit 0
