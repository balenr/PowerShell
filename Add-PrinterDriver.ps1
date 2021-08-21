#requires -Version 5.1
function Add-PrinterDriver {
    <#
    .SYNOPSIS
        Adds printer drivers to the local computer from a specified print server.
    .DESCRIPTION
        Adds printer drivers to the local computer from a specified print server.
        The function collects all shared printer objects from the specified print server
        and installs them on the local computer if not already installed.
        One mandatory parameter: PrintServer
    .PARAMETER PrintServer
        The name of the print server to add printer drivers from
    .PARAMETER Clean
        Switch parameter which deletes all network printer connections for the current user.
    .EXAMPLE
        Add-PrinterDriver -PrintServer srv01.domain.local

        Add printer drivers from the specified print server
    .EXAMPLE
        Add-PrinterDriver -PrintServer srv01.domain.local -Clean

        Add printer drivers from the specified print server, then removes all network printer connections for the current user.
    .EXAMPLE
        Add-PrinterDriver -PrintServer srv01.domain.local -Verbose

        Add printer drivers from the specified print server with the -Verbose switch parameter
    .NOTES
        AUTHOR:    René van Balen
        LASTEDIT:  21-08-2021

        ORIGINAL AUTHOR:    Jan Egil Ring
        BLOG:               http://blog.powershell.no

        You have a royalty-free right to use, modify, reproduce, and
        distribute this script file in any way you find useful, provided that
        you agree that the creator, owner above has no warranty, obligations,
        or liability for such use.
    #>
    [CmdletBinding()]
    param (
        # The Print Server
        [Parameter(Mandatory)]
        [string]$PrintServer,

        # Clean Printer Connections
        [switch]$Clean
    )

    $AllPrinters = Get-Printer -ComputerName $PrintServer | Where-Object {$_.Shared -eq $true}
    $Drivers = @($AllPrinters | Select-Object -Property DriverName -Unique)
    $Printers = @()
    foreach ($item in $Drivers) {
        $Printers += @($AllPrinters | Where-Object {$_.DriverName -eq $item.DriverName})[0]
    }

    $LocalDrivers = @()
    foreach ($driver in (Get-PrinterDriver)) {
        $LocalDrivers += @($driver.Name)
    }

    $CurrentPrinter = 1

    foreach ($Printer in $Printers) {

        Write-Progress -Activity "Installing printers..." -Status "Current printer: $($Printer.Name)" -Id 1 -PercentComplete (($CurrentPrinter/$Printers.Count)*100)

        $ConnectionName = "\\$($Printer.ComputerName)\$($Printer.Name)"
        Write-Verbose "Processing: $ConnectionName"

        $OutputObject = @{}
        $OutputObject.DriverName = $Printer.DriverName

        $InstalledLocally = $LocalDrivers | Where-Object {$_ -eq $Printer.DriverName}

        if (-not $InstalledLocally) {
            Write-Verbose "$($Printer.DriverName) is not installed locally, installing"
            try {
                Add-Printer -ConnectionName $ConnectionName -ErrorAction Stop
                $OutputObject.Result = "Installed"
            }
            catch {
                $ErrorMessage = $_.Exception.Message
                Write-Verbose "Failed to connect to $ConnectionName"
                Write-Verbose $ErrorMessage
                $OutputObject.Result = "Not installed"
                $OutputObject.ErrorMessage = $ErrorMessage
            }

        } else {
            Write-Verbose "$($Printer.DriverName) is already installed locally, skipping"
            $OutputObject.Result = "Already installed"
        }

        New-Object -TypeName PSObject -Property $OutputObject

        $CurrentPrinter ++

    }

    if($Clean) {
        Get-Printer | Where-Object {$_.Type -eq "Connection" -and $_.ComputerName -eq $PrintServer} |
        Remove-Printer
    }
}
