Function Update-VMWareVMTemplate {

<#
    .SYNOPSIS
        Install patches on VMware Template.

    .DESCRIPTION
        Installs patches.  Currently only works with WIndows patches.

    .PARAMETER Template
        Template object or Template name.

    .PARAMETER GuestCredential
        Admin credentials for the templates guest OS.

    .EXAMPLE
        Install Updates on template given a name.

        Update-VMwareVMTemplate -Template 'Windows2019' -GuestCredential $Cred

    .EXAMPLE
        Install Updates on a template 

        $Template = Get-Template 'Windows2019'
        Update-VMwareVMTemplate -Template $Template -GuestCredential $Cred

    .NOTES
        Author : Jeff Buenting
        Date : 2020 DEC 24 (Merry Christmas)


        TODO : Get-Job so we can wait until the patches are installed.
#>

    [CmdletBinding()]
    Param (
        [Parameter (Mandatory = $True) ]
        [PSObject]$Template,

        [Parameter (Mandatory = $True) ]
        [PSCredential]$GuestCredential   
    )
    
    # ----- Get the template if it $Template is not a template
    if ( $Template.GetType().Name -ne 'TemplateImpl' ) {
        Try {
            Write-Verbose "Retrieving Template $Template"
            $Template = Get-Template -Name $Template -ErrorAction Stop
        }
        Catch {
            $ExceptionMessage = $_.Exception.Message
            $ExceptionType = $_.Exception.GetType().Fullname
            Throw "Update-VMwareVMTemplate : Template does not exist.`n`n     $ExceptionMessage`n`n $ExceptionType"
        }
    }

    # ----- Convert Template to VM
    Write-Verbose "Converting $($Template.Name) to VM"

    Set-Template -Template $Template -ToVM | Write-Verbose

    $VM = Get-VM -Name $Template.Name 

    Start-VM -VM $VM | write-Verbose

    Wait-VMState -VM $VM -State PoweredON

    # ----- Scan and install Updates
    # https://4sysops.com/archives/scan-download-and-install-windows-updates-with-powershell/
    $Cmd = @"
        $updates = Start-WUScan 
        Install-WUUpdates -Updates $updates
"@

    Invoke-VMScript -VM $VM -ScriptText $Cmd -GuestCredential $GuestCredential

    # ----- How long to wait for patches to install
    Start-Sleep -Seconds 120


    # ----- Shut down the VM
    Shutdown-VMGuest -vm $VM -Confirm:$False | Write-Verbose

    Wait-VMState -VM $VM -State PoweredOff

    # ----- Convert to Template
    Set-VM -VM $VM -ToTemplate -Confirm:$False | Write-Verbose
}