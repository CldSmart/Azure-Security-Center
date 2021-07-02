#***************************************************************************************************************
# This script will import a CSV file, based on the "checkForMMAExtension" script output file
# and install the MMA extension on all the VMs found in that CSV
#**************************************************************************************************************

$ErrorActionPreference = 'Stop'

#Login-AzAccount

#variables
$VMinputFolder = "D:\temp\"
$VMinputFile = "ASC-outputFile.csv"  # We will install the MMA VM extension based on the VMs in this file


#fill in your workspaceID, workspaceKey, resourcegroup name and location
$publicSettings = @{"workspaceId" = "<YourWorkspaceID>" }
$protectedSettings = @{"workspaceKey" = "<YourWorkspaceKey>" }

# Importing CSV file
Write-Host "*** Trying to import file:" ($VMinputFolder + $VMinputFile) " ***" -ForegroundColor Green
try {
    $targetVMs = Import-Csv -Path ($VMinputFolder + $VMinputFile)
    Write-Host "Your input file contains" $targetVMs.VMname.count "VM's" -ForegroundColor Green
}
catch { Write-Host "Could not open input file.... Please your path and filename." -ForeGroundColor Red }

$answer = Read-Host "Continue installation? (yes/no)"
if ($answer -eq "yes") {
    Write-Host "Starting VM extension installation" -ForegroundColor Green
}
else {
    Write-Host "Aborting installation" -ForegroundColor Red
    break
}
$subName = ""
# install VM extension
foreach ($VM in $targetVMs) {
    Write-Output "`r`n"
    Write-Host "*** Trying to install the MMA VM extension on" $VM.VMname "- Subscription:" $VM.SubScriptionName -ForegroundColor Green
   
    if ($VM.OsType -eq "Windows") {
        try {
            if ($subName -ne $VM.SubScriptionName) {
                $subName = $VM.SubScriptionName
                Write-Host "Changing to subscription:" $VM.SubScriptionName -ForegroundColor Green
                Set-AzContext -Subscription $VM.SubScriptionName
            }
            
           
            try {
                # check if the VM extension has already been installed
                # the name search is not good, the same extension can be installed with different name 
                #Get-AzVMExtension -VMName $VM.VMname -ResourceGroupName $VM.ResourceGroup -Name "MicrosoftMonitoringAgent" | Select-Object VMName, ProvisioningState, ResourceGroupName
                $myExtensions = Get-AzVMExtension -VMName $VM.VMname -ResourceGroupName $VM.ResourceGroup | Where-Object { $_.ExtensionType -eq "MicrosoftMonitoringAgent" -and $_.ProvisioningState -eq "Succeeded" }
                if ($myExtensions) {
                    Write-Host "Extension has already been installed, so skipping...." -ForegroundColor Red
                }
                else {
                    Write-Host "Installing VM Extension of type Windows....please wait..." -ForeGroundColor Green
                    Set-AzVMExtension -VMName $VM.VMname -ResourceGroupName $VM.ResourceGroup `
                        -Name MicrosoftMonitoringAgent `
                        -TypeHandlerVersion 1.0 `
                        -Publisher Microsoft.EnterpriseCloud.Monitoring  `
                        -ExtensionType MicrosoftMonitoringAgent `
                        -Settings $publicSettings `
                        -ProtectedSettings $protectedSettings `
                        -Location $VM.Location
                    Write-Host "Done!" -ForeGroundColor Green
                }
                
            }
            catch {
                $ErrorMessage = $_.Exception.Message
                Write-Host "Could not set subscription or could not install the VM extension" -ForegroundColor Red
                Write-Host $ErrorMessage -ForegroundColor Red
            }

        
        }
        catch { 
            $ErrorMessage = $_.Exception.Message
            Write-Host "Could not set subscription or could not install the VM extension" -ForegroundColor Red 
            Write-Host $ErrorMessage -ForegroundColor Red
        }
        
    }
    #VM is of type Linux
    elseif ($VM.OsType -eq "Linux") {
        Set-AzContext -Subscription $VM.SubScriptionName
        Write-Host "Installing VM Extension of type Linux....please wait..." -ForeGroundColor Green
        try {
            # check if the VM extension has already been installed
            Get-AzVMExtension -VMName $VM.VMname -ResourceGroupName $VM.ResourceGroup -Name "MicrosoftMonitoringAgent" | Select-Object VMName, ProvisioningState, ResourceGroupName
            Write-Host "Extension has already been installed, so skipping...." -ForegroundColor Red

        }
        catch {
            Set-AzVMExtension -VMName $VM.VMname -ResourceGroupName $VM.ResourceGroup `
                -Name MicrosoftMonitoringAgent `
                -TypeHandlerVersion 1.7 `
                -Publisher Microsoft.EnterpriseCloud.Monitoring  `
                -ExtensionType OmsAgentForLinux `
                -Settings $publicSettings `
                -ProtectedSettings $protectedSettings `
                -Location $VM.Location
            Write-Host "Done!" -ForeGroundColor Green
        }
    }
    else {
        Write-Host "No valid OS type found!" -ForegroundColor Red
    }
}

