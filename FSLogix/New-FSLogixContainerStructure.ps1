# Script for creating a FSLogix file share for Profile containers
# Alex Henstra
# June 3 2019
#
$VerbosePreference = "Continue"

# Change Path and folder variables
# Path to local folder
$path = "D:\"

# Folder and share name
$fslogixRootFolder = "FSLogix"


############# Start Script ###########

# install and import AD powershell module if needed
$ADinstalled = (Get-WindowsFeature -Name RSAT-AD-PowerShell).Installed
if ($false -eq $ADinstalled) {
    Write-Verbose "Installing AD PowerShell module.."
    Install-WindowsFeature RSAT-AD-PowerShell
}

Import-Module -Name ActiveDirectory

$newFolderFull = $path + $fslogixRootFolder
Write-Verbose "New Folder will be: $newFolderFull"

# Create folders
Write-Verbose "Add base Folder.."
New-Item $newFolderFull -ItemType Directory | Out-Null
Write-Verbose "Add RedirXMLSourceFolder Folder.."
New-Item $newFolderFull\RedirXMLSourceFolder -ItemType Directory | Out-Null
Write-Verbose "Add Rules Folder.."
New-Item $newFolderFull\Rules -ItemType Directory | Out-Null


# Create new share with permissions
Write-Verbose "Add share.."
$actualshare = New-SmbShare -Name "$fslogixRootFolder$" -Path $newFolderFull -CachingMode "none" -FolderEnumerationMode "AccessBased" -FullAccess "Domain Admins" -ChangeAccess "authenticated users"
Write-Verbose "SMB share: $($actualshare.Name), created for folder: $($actualshare.Path)"


# Remove inheritance rights from the new folder
Write-Verbose "Remove Inheritance.."
$acl = Get-Acl -Path $newFolderFull
$acl.SetAccessRuleProtection($True, $True)
Set-Acl -Path $newFolderFull -AclObject $acl | Out-Null
$inheritance = Get-Acl -Path $newFolderFull | Select-Object @{Name = "Path"; Expression = { Convert-Path $_.Path } }, AreAccessRulesProtected
$output = "Inheritance block status for folder: "
$output += $inheritance.path
$output += " is: "
$output += $inheritance.AreAccessRulesProtected
Write-Verbose $output


# Remove Users
$objUser = New-Object System.Security.Principal.NTAccount("BUILTIN\USERS")
$colRights = [System.Security.AccessControl.FileSystemRights]"CreateFiles, AppendData"
$InheritanceFlag = [System.Security.AccessControl.InheritanceFlags]::None
$PropagationFlag = [System.Security.AccessControl.PropagationFlags]::None
$objType = [System.Security.AccessControl.AccessControlType]::Allow

#combine the variables into a single filesystem access rule
$objACE = New-Object System.Security.AccessControl.FileSystemAccessRule($objUser, $colRights, $InheritanceFlag, $PropagationFlag, $objType)

#get the current ACL from the folder
$objACL = Get-Acl $newFolderFull

#remove the access permissions from the ACL variable
$objACL.removeaccessruleall($objACE)

#remove the permissions from the actual folder by re-applying the modified ACL
Set-Acl $newFolderFull $objACL | Out-Null

#Base folder start
#get the current ACL from the folder
$objACL = Get-Acl $newFolderFull

# Add domain Users
$objUser = New-Object System.Security.Principal.NTAccount("Domain Users")
$colRights = [System.Security.AccessControl.FileSystemRights]"Write, ReadAndExecute, Synchronize"
$InheritanceFlag = [System.Security.AccessControl.InheritanceFlags]::None
$PropagationFlag = [System.Security.AccessControl.PropagationFlags]::"NoPropagateInherit"
$objType = [System.Security.AccessControl.AccessControlType]::Allow

#combine the variables into a single filesystem access rule
$objACE = New-Object System.Security.AccessControl.FileSystemAccessRule($objUser, $colRights, $InheritanceFlag, $PropagationFlag, $objType)
$objACL.AddAccessRule($objACE)
Set-Acl $newFolderFull $objACL | Out-Null

#Display result
$users = Get-Acl -Path $newFolderFull | Select-Object @{Name = "Path"; Expression = { Convert-Path $_.Path } }, AccessToString
$output = "User Rights for: "
$output += $users.Path
Write-Verbose $output

Write-Verbose $users.AccessToString

#Base folder end


#Rules folder start
#get the current ACL from the folder
$objACL = Get-Acl $newFolderFull\Rules

# Add domain computers
$objUser = New-Object System.Security.Principal.NTAccount("Domain Computers")
$colRights = [System.Security.AccessControl.FileSystemRights]"Write, ReadAndExecute, Synchronize"
$InheritanceFlag = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit,ObjectInherit"
$PropagationFlag = [System.Security.AccessControl.PropagationFlags]::"NoPropagateInherit"
$objType = [System.Security.AccessControl.AccessControlType]::Allow

#combine the variables into a single filesystem access rule
$objACE = New-Object System.Security.AccessControl.FileSystemAccessRule($objUser, $colRights, $InheritanceFlag, $PropagationFlag, $objType)
$objACL.AddAccessRule($objACE)
Set-Acl $newFolderFull\Rules $objACL | Out-Null

#Display result
$users = Get-Acl -Path $newFolderFull\Rules | Select-Object @{Name = "Path"; Expression = { Convert-Path $_.Path } }, AccessToString
$output = "User Rights for: "
$output += $users.Path
Write-Verbose $output

Write-Verbose $users.AccessToString

#Rules folder end


#RedirXMLSourceFolder folder start
#get the current ACL from the folder
$objACL = Get-Acl $newFolderFull\RedirXMLSourceFolder

# Add domain computers
$objUser = New-Object System.Security.Principal.NTAccount("Domain Users")
$colRights = [System.Security.AccessControl.FileSystemRights]"Write, ReadAndExecute, Synchronize"
$InheritanceFlag = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit,ObjectInherit"
$PropagationFlag = [System.Security.AccessControl.PropagationFlags]::"NoPropagateInherit"
$objType = [System.Security.AccessControl.AccessControlType]::Allow

#combine the variables into a single filesystem access rule
$objACE = New-Object System.Security.AccessControl.FileSystemAccessRule($objUser, $colRights, $InheritanceFlag, $PropagationFlag, $objType)
$objACL.AddAccessRule($objACE)
Set-Acl $newFolderFull\RedirXMLSourceFolder $objACL | Out-Null

#Display result
$users = Get-Acl -Path $newFolderFull\RedirXMLSourceFolder | Select-Object @{Name = "Path"; Expression = { Convert-Path $_.Path } }, AccessToString
$output = "User Rights for: "
$output += $users.Path
Write-Verbose $output

Write-Verbose $users.AccessToString

#RedirXMLSourceFolder folder end