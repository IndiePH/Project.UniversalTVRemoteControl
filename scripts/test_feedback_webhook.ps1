# Smoke-test the feedback webhook auth contract.
param(
  [Parameter(Mandatory = $true)]
  [string]$Token,

  [string]$Url = 'https://script.google.com/macros/s/AKfycbyYdrlh8oVk1BwA2w5xa6JGW0kPwGSRaSElpqmClz2VyfhPpEX3rRvT3oTPbcS8w4HTWQ/exec'
)

$ErrorActionPreference = 'Stop'

function Invoke-FeedbackPost {
  param(
    [string]$AuthToken
  )

  $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  $body = @{
    submittedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    category    = 'bug'
    platform    = 'android'
    appVersion  = '1.4.0+17'
    message     = "Webhook auth smoke test $stamp - please ignore."
  } | ConvertTo-Json -Compress

  $headers = @{}
  if ($AuthToken) {
    $headers['X-Feedback-Token'] = $AuthToken
  }

  return Invoke-RestMethod -Uri $Url -Method POST -ContentType 'application/json' -Headers $headers -Body $body
}

Write-Host '1) Unauthorized POST (expect ok:false after FEEDBACK_TOKEN is set)...'
$unauth = Invoke-FeedbackPost -AuthToken ''
Write-Host "   response=$($unauth | ConvertTo-Json -Compress)"

Write-Host '2) Authorized POST (expect ok:true)...'
$auth = Invoke-FeedbackPost -AuthToken $Token
Write-Host "   response=$($auth | ConvertTo-Json -Compress)"

if (-not $auth.ok) {
  Write-Error 'Authorized POST did not return ok:true. Confirm Apps Script FEEDBACK_TOKEN matches.'
  exit 1
}

if ($unauth.ok) {
  Write-Warning 'Unauthorized POST still succeeded - set FEEDBACK_TOKEN in Apps Script Script properties.'
  exit 2
}

Write-Host 'Webhook auth check passed.'
