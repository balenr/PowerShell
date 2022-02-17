<#
.SYNOPSIS
    This script allows updating PKI objects in Active Directory for the
    cross-forest certificate enrollment.
.DESCRIPTION
    This script allows updating PKI objects in Active Directory for the
    cross-forest certificate enrollment.
.PARAMETER ObjectType
    Type of object to process, if omitted then all object types are processed.
    CA         -- Process CA object(s)
    Template   -- Process Template object(s)
    OID        -- Process OID object(s)
.PARAMETER ObjectCN
    Common name of the object to process, do not include the cn= (ie "User" and not "CN=User").
    This option is only valid if -ObjectType is also specified.
.EXAMPLE
    PS C:\> PKISync.ps1 -SourceForest domain1.local -TargetForest domain2.local -Type Template -CN WebServer -Force
    Copy a certificate template from one forest to another
.NOTES
    This sample script is not supported under any Microsoft standard support
    program or service. This sample script is provided AS IS without warranty of
    any kind. Microsoft further disclaims all implied warranties including,
    without limitation, any implied warranties of merchantability or of fitness
    for a particular purpose. The entire risk arising out of the use or
    performance of the sample scripts and documentation remains with you. In no
    event shall Microsoft, its authors, or anyone else involved in the creation,
    production, or delivery of the scripts be liable for any damages whatsoever
    (including, without limitation, damages for loss of business profits, business
    interruption, loss of business information, or other pecuniary loss) arising
    out of the use of or inability to use this sample script or documentation,
    even if Microsoft has been advised of the possibility of such damages.
#>

[CmdletBinding(SupportsShouldProcess)]
param (
    # DNS of the forest to process object from.
    [Parameter(Mandatory)]
    [string] $SourceForestName,
    # DNS of the forest to process object to.
    [Parameter(Mandatory)]
    [string] $TargetForestName,
    # Common name of the object to process, do not include the cn= (ie "User" and not "CN=User").
    [Alias("cn")]
    [string] $ObjectCN = $null,
    # Type of object to process, if omitted then all object types are processed.
    [ValidateSet("All","CA","OID","Template")]
    [Alias("type")]
    [string] $ObjectType = "all",
    # Will delete object in the target forest if it exists.
    [switch] $DeleteOnly,
    # DNS of the DC in the source forest to process object from.
    [string] $SourceDC,
    # DNS of the DC in the target forest to process object to.
    [string] $TargetDC,
    # Force overwrite of existing objects when copying. Ignored when deleting.
    [Alias("f")]
    [switch] $Force
)

#
# Build a list of attributes to copy for some object type
#
function GetSchemaSystemMayContain {

    param (
        $ForestContext,
        $ObjectType
    )

    #
    # first get all attributes that are part of systemMayContain list
    #
    $SchemaDE = [System.DirectoryServices.ActiveDirectory.ActiveDirectorySchemaClass]::FindByName($ForestContext, $ObjectType).GetDirectoryEntry()
    $SystemMayContain = $SchemaDE.systemMayContain

    #
    # if schema was upgraded with adprep.exe, we need to check mayContain list as well
    #
    if ($null -ne $SchemaDE.mayContain) {
        $MayContain = $SchemaDE.mayContain
        foreach ($attr in $MayContain) {
            $SystemMayContain.Add($attr)
        }
    }

    #
    # special case some of the inherited attributes
    #
    if (-1 -eq $SystemMayContain.IndexOf("displayName")) {
        $SystemMayContain.Add("displayName")
    }
    if (-1 -eq $SystemMayContain.IndexOf("flags")) {
        $SystemMayContain.Add("flags")
    }
    if ($objectType.ToLower().Contains("template") -and -1 -eq $SystemMayContain.IndexOf("revision")) {
        $SystemMayContain.Add("revision")
    }

    return $SystemMayContain
}

#
# Copy or delete all objects of some type
#
function ProcessAllObjects {

    param(
        $SourcePKIServicesDE,
        $TargetPKIServicesDE,
        $RelativeDN
    )

    $SourceObjectsDE = $SourcePKIServicesDE.psbase.get_Children().find($RelativeDN)
    $ObjectCN = $null

    foreach ($ChildNode in $SourceObjectsDE.psbase.get_Children()) {
        # if some object failed, we will try to continue with the rest
        trap {
            # CN maybe null here, but its ok. Doing best effort.
            Write-Warning "Error while coping an object. CN=$ObjectCN"
            Write-Warning $_
            Write-Warning $_.InvocationInfo.PositionMessage
            continue
        }

        $ObjectCN = $ChildNode.psbase.Properties["cn"]
        ProcessObject $SourcePKIServicesDE $TargetPKIServicesDE $RelativeDN $ObjectCN
        $ObjectCN = $null
    }

}

#
# Copy or delete an object
#
function ProcessObject {

    [CmdletBinding(SupportsShouldProcess)]
    param(
        $SourcePKIServicesDE,
        $TargetPKIServicesDE,
        $RelativeDN,
        $ObjectCN
    )

    $SourceObjectContainerDE = $SourcePKIServicesDE.psbase.get_Children().find($RelativeDN)
    $TargetObjectContainerDE = $TargetPKIServicesDE.psbase.get_Children().find($RelativeDN)

    #
    # when copying make sure there is an object to copy
    #
    if ($FALSE -eq $Script:DeleteOnly) {
        $DSSearcher = [System.DirectoryServices.DirectorySearcher]$SourceObjectContainerDE
        $DSSearcher.Filter = "(cn=" + $ObjectCN + ")"
        $SearchResult = $DSSearcher.FindAll()
        if (0 -eq $SearchResult.Count) {
            Write-Verbose "Source object does not exist: CN=$ObjectCN,$RelativeDN"
            return
        }
        $SourceObjectDE = $SourceObjectContainerDE.psbase.get_Children().find("CN=" + $ObjectCN)
    }

    #
    # Check to see if the target object exists, if it does delete if -Force is enabled.
    # Also delete is this a deletion only operation.
    #
    $DSSearcher = [System.DirectoryServices.DirectorySearcher]$TargetObjectContainerDE
    $DSSearcher.Filter = "(cn=" + $ObjectCN + ")"
    $SearchResult = $DSSearcher.FindAll()
    if ($SearchResult.Count -gt 0) {
        $TargetObjectDE = $TargetObjectContainerDE.psbase.get_Children().find("CN=" + $ObjectCN)

        if ($DeleteOnly) {
            Write-Verbose "Deleting: $($TargetObjectDE.DistinguishedName)"
            if ($PSCmdlet.ShouldProcess($TargetObjectDE.DistinguishedName, "DELETE")) {
                $TargetObjectContainerDE.psbase.get_Children().Remove($TargetObjectDE)
            }
            return
        }
        elseif ($Force) {
            Write-Verbose "OverWriting: $TargetObjectDE.DistinguishedName"
            if ($PSCmdlet.ShouldProcess($TargetObjectDE.DistinguishedName, "OVERWRITE")) {
                $TargetObjectContainerDE.psbase.get_Children().Remove($TargetObjectDE)
            }
        }
        else {
            Write-Warning ("Object exists, use -f to overwrite. Object: " + $TargetObjectDE.DistinguishedName)
            return
        }
    }
    else {
        if ($DeleteOnly) {
            Write-Warning "Can't delete object. Object doesn't exist. Object: $ObjectCN, $($TargetObjectContainerDE.DistinguishedName)"
            return
        }
        else {
            Write-Verbose "Copying Object: $($SourceObjectDE.DistinguishedName)"
        }
    }

    #
    # Only update the object if this is not a dry run
    #
    if ($PSCmdlet.ShouldProcess($TargetObjectContainerDE, "UPDATE") -and $FALSE -eq $DeleteOnly) {
        #Create new AD object
        $NewDE = $TargetObjectContainerDE.psbase.get_Children().Add("CN=" + $ObjectCN, $SourceObjectDE.psbase.SchemaClassName)

        #Obtain systemMayContain for the object type from the AD schema
        $ObjectMayContain = GetSchemaSystemMayContain $SourceForestContext $SourceObjectDE.psbase.SchemaClassName
        #Copy attributes defined in the systemMayContain for the object type
        foreach ($Attribute in $ObjectMayContain) {
            $AttributeValue = $SourceObjectDE.psbase.Properties[$Attribute].Value
            if ($null -ne $AttributeValue) {
                $NewDE.psbase.Properties[$Attribute].Value = $AttributeValue
                $NewDE.psbase.CommitChanges()
            }
        }
        #Copy secuirty descriptor to new object. Only DACL is copied.
        $BinarySecurityDescriptor = $SourceObjectDE.psbase.ObjectSecurity.GetSecurityDescriptorBinaryForm()
        $NewDE.psbase.ObjectSecurity.SetSecurityDescriptorBinaryForm($BinarySecurityDescriptor, [System.Security.AccessControl.AccessControlSections]::Access)
        $NewDE.psbase.CommitChanges()
    }
}

#
# Get parent container for all PKI objects in the AD
#
function GetPKIServicesContainer {

    param(
        [System.DirectoryServices.ActiveDirectory.DirectoryContext] $ForestContext,
        $dcName
    )

    $ForObj = [System.DirectoryServices.ActiveDirectory.Forest]::GetForest($ForestContext)
    $DE = $ForObj.RootDomain.GetDirectoryEntry()

    if ("" -ne $dcName) {
        $newPath = [System.Text.RegularExpressions.Regex]::Replace($DE.psbase.Path, "LDAP://\S*/", "LDAP://" + $dcName + "/")
        $DE = New-Object System.DirectoryServices.DirectoryEntry $newPath
    }

    $PKIServicesContainer = $DE.psbase.get_Children().find("CN=Public Key Services,CN=Services,CN=Configuration")
    return $PKIServicesContainer
}

#########################################################
# Main script code
#########################################################

#
# All errors are fatal by default unless there is another 'trap' with 'continue'
#
trap {
    Write-Error "The script has encoutnered a fatal error. Terminating script."
    break
}

#
# Get a hold of the containers in each forest
#
Write-Verbose "Target Forest: $($TargetForestName.ToUpper())"
$TargetForestContext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext Forest, $TargetForestName
$TargetPKIServicesDE = GetPKIServicesContainer $TargetForestContext $TargetDC

# Only need source forest when copying
if ($DeleteOnly) {
    $SourcePKIServicesDE = $TargetPKIServicesDE
}
else {
    Write-Verbose "Source Forest: $($SourceForestName.ToUpper())"
    $SourceForestContext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext Forest, $SourceForestName
    $SourcePKIServicesDE = GetPKIServicesContainer $SourceForestContext $SourceDC
}

if ("" -ne $ObjectType) { Write-Verbose "Object Category to process: $($ObjectType.ToUpper())" }

#
# Process the command
#
switch ($ObjectType.ToLower()) {
    all {
        Write-Verbose "Enrollment Serverices Container"
        ProcessAllObjects $SourcePKIServicesDE $TargetPKIServicesDE "CN=Enrollment Services"
        Write-Verbose "Certificate Templates Container"
        ProcessAllObjects $SourcePKIServicesDE $TargetPKIServicesDE "CN=Certificate Templates"
        Write-Verbose "OID Container"
        ProcessAllObjects $SourcePKIServicesDE $TargetPKIServicesDE "CN=OID"
    }
    ca {
        if ($null -eq $ObjectCN) {
            ProcessAllObjects $SourcePKIServicesDE $TargetPKIServicesDE "CN=Enrollment Services"
        }
        else {
            ProcessObject $SourcePKIServicesDE $TargetPKIServicesDE "CN=Enrollment Services" $ObjectCN
        }
    }
    oid {
        if ($null -eq $ObjectCN) {
            ProcessAllObjects $SourcePKIServicesDE $TargetPKIServicesDE "CN=OID"
        }
        else {
            ProcessObject $SourcePKIServicesDE $TargetPKIServicesDE "CN=OID" $ObjectCN
        }
    }
    template {
        if ($null -eq $ObjectCN) {
            ProcessAllObjects $SourcePKIServicesDE $TargetPKIServicesDE "CN=Certificate Templates"
        }
        else {
            ProcessObject $SourcePKIServicesDE $TargetPKIServicesDE "CN=Certificate Templates" $ObjectCN
        }
    }
    default {
        Write-Warning ("Unknown object type: " + $ObjectType.ToLower())
        exit 87
    }
}
