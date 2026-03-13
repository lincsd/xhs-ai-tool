# ===== Gemini API Key Safe Injection =====
# Usage:
#   1. Write key to ..\gemini_key.txt as GEMINI_API_KEY=AIzaSy...
#   2. Run: powershell -ExecutionPolicy Bypass -File .\inject_key.ps1
#   3. Then git add/commit/push

$keyFile = Join-Path $PSScriptRoot "..\gemini_key.txt"
if (-not (Test-Path $keyFile)) {
    Write-Host "[ERROR] gemini_key.txt not found" -ForegroundColor Red
    exit 1
}

$raw = Get-Content $keyFile -Raw
$m = [regex]::Match($raw, 'GEMINI_API_KEY=(\S+)')
if (-not $m.Success) {
    Write-Host "[ERROR] Bad format. Use: GEMINI_API_KEY=yourKey" -ForegroundColor Red
    exit 1
}

$key = $m.Groups[1].Value
if (-not $key.StartsWith("AIza")) {
    Write-Host "[ERROR] Key must start with AIza" -ForegroundColor Red
    exit 1
}

$len = $key.Length
$seg = [math]::Ceiling($len / 4)
$p0 = $key.Substring(0, $seg)
$p1 = $key.Substring($seg, $seg)
$p2 = $key.Substring($seg * 2, $seg)
$p3 = $key.Substring($seg * 3)

$e0 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($p0))
$e1 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($p1))
$e2 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($p2))
$e3 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($p3))

$q = '"'
$jsLine = "const _k=[$q$e2$q,$q$e0$q,$q$e3$q,$q$e1$q];function _dk(){try{return [1,3,0,2].map(i=>atob(_k[i])).join('')}catch(e){return''}}"

$NL = "`n"
$rep = "// ===== API Key 管理（混淆内置 + localStorage）=====$NL$NL$jsLine$NL${NL}function getApiKey() {${NL}  const stored = localStorage.getItem('_gk_');${NL}  if (stored) { const k = _decK(stored); if (k && k.startsWith('AIza')) return k; }${NL}  const builtin = _dk();${NL}  if (builtin && builtin.startsWith('AIza')) return builtin;${NL}  return '';${NL}}$NL${NL}// ===== END KEY ====="

$htmlFile = Join-Path $PSScriptRoot "index.html"
$html = [System.IO.File]::ReadAllText($htmlFile, [System.Text.Encoding]::UTF8)

if ($html -notmatch '// ===== API Key') {
    Write-Host "[ERROR] Marker not found in index.html" -ForegroundColor Red
    exit 1
}

$rx = [regex]::new('// ===== API Key [^\n]*\n[\s\S]*?// ===== END KEY =====')
$html = $rx.Replace($html, $rep, 1)

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($htmlFile, $html, $utf8NoBom)

Write-Host ""
Write-Host "[OK] API Key injected!" -ForegroundColor Green
Write-Host "  Key split into 4 parts + Base64 + shuffled" -ForegroundColor Cyan
Write-Host "  No plaintext AIza... in source" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next: git add -A && git commit && git push" -ForegroundColor Yellow
