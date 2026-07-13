try { $null = [Console]::In.ReadToEnd() } catch {}

$status = & git status --porcelain 2>&1
if (-not $status) {
    Write-Output '{}'
    exit 0
}

& git add -A 2>&1 | Out-Null
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
& git commit -m "auto-save: $timestamp" 2>&1 | Out-Null

$branch = & git rev-parse --abbrev-ref HEAD 2>&1
& git push origin $branch 2>&1 | Out-Null

Write-Output '{}'
exit 0
