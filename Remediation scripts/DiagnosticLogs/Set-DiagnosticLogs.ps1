[CmdletBinding()]
param()

$myWorkspace = Get-AzOperationalInsightsWorkspace

<# 
# set NSG Diagnostics
$myNsgs = Get-AzNetworkSecurityGroup
foreach ($nsg in $myNsgs) {
    $myDiag = Get-AzDiagnosticSetting -ResourceId $nsg.Id
    if ($myDiag) {
        Write-Host "Found diagnostic settings "$myDiag.Name", skipping "$nsg.Name -ForeGroundColor Green
    }
    else {
        Set-AzDiagnosticSetting -Name ($nsg.Name + "-diag") `
            -ResourceId $nsg.Id -Enabled $true `
            -WorkspaceId $myWorkspace.ResourceId
    }
}
#>
$myFile = ".\unsupportedTypes.txt"
[string[]]$unsupportedTypes = Get-Content -Path $myFile
$myResources = Get-AzResource
$myExistingCounter = 0 
$myCounter = 0 
foreach ($res in $myResources) {
    if ($res.ResourceType -notin $unsupportedTypes) {   
        $myDiag = $null
        Write-Verbose ("Trying to get  diagnostic settings for " + $res.Name )
        $err = $null
        $myDiag = Get-AzDiagnosticSetting -ResourceId $res.ResourceId -ErrorAction SilentlyContinue -ErrorVariable err -WarningAction SilentlyContinue
        if ($myDiag) {
            Write-Verbose ("Found diagnostic settings " + $myDiag.Name + ", skipping " + $res.Name )
            $myExistingCounter++
        }
        elseif (!$err -or $err -contains "Not Found") {
            try {
                Write-Verbose ("Creating diagnostic settings " + $myDiag.Name + " for " + $res.Name )
                $myDiag = Set-AzDiagnosticSetting -WorkspaceId $myWorkspace.ResourceId -Name ($res.Name + "-diag") -ResourceId $res.ResourceId -Enabled $true -WarningAction SilentlyContinue -ErrorAction SilentlyContinue -ErrorVariable err                    
                if (!$err) {
                    $myCounter++
                    Write-Host "Created diagnostic settings "$res.Name"-diag" -ForeGroundColor Green     
                }
                elseif ($err -like "*ResourceTypeNotSupported*") {
                    Write-Verbose ($res.Name + " does not support diagnostic logging, adding the resource type to list" )
                    $res.ResourceType >> $myFile
                    [string[]]$unsupportedTypes = Get-Content -Path $myFile
                }                   
            }
            catch {
                #$ErrorMessage = $_.Exception.Message
                Write-Host "Could not create diagnostic settings for "$res.Name -ForegroundColor Red
                #Write-Host $ErrorMessage -ForegroundColor Red
            }
        }
        elseif ($err -like "*Bad Request*") {
            Write-Verbose ($res.Name + " does not support diagnostic logging, adding to list" )
            $res.ResourceType >> $myFile
            [string[]]$unsupportedTypes = Get-Content -Path $myFile
        }
    }
    else{
        Write-Verbose ($res.Name + " does not support diagnostic logging" )
    }
}
Write-Host "Completed checking "($myResources.Count)"resources. Found "$myExistingCounter" diagnostic settings. Created "$myCounter" new diagnostic settings." -ForeGroundColor Green
