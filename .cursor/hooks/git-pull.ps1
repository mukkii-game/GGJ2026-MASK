try { $null = [Console]::In.ReadToEnd() } catch {}

$branch = & git rev-parse --abbrev-ref HEAD 2>&1
& git fetch origin $branch 2>&1 | Out-Null
$result = & git pull origin $branch --ff-only 2>&1

Write-Output '{}'
exit 0
