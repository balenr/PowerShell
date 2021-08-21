# Input Parameters for
# - VmName: name of the vm to perform action to
# - ResourceGroupName: resource group where the vm belongs to
# - VmAction:action to perform (startup or shutdown)
Param(
    [string]$VmName,
    [string]$ResourceGroupName,
    [ValidateSet("Startup", "Shutdown")]
    [string]$VmAction
)

# Authenticate with your Automation Account
$Conn = Get-AutomationConnection -Name AzureRunAsConnection
Add-AzureRMAccount -ServicePrincipal -Tenant $Conn.TenantID `
-ApplicationID $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint

# Startup VM
IF ($VmAction -eq "Startup") {
    Start-AzureRmVM -Name $VmName -ResourceGroupName $ResourceGroupName
}

# Shutdown VM
IF ($VmAction -eq "Shutdown") {
    Stop-AzureRmVM -Name $VmName -ResourceGroupName $ResourceGroupName -Force
}