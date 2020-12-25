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

    .LINK
        https://github.com/MicrosoftDocs/windows-powershell-docs

    .NOTES
        Author : Jeff Buenting
        Date : 2020 DEC 24 (Merry Christmas)
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
    $UpdateCmd = @"
        `$updates = Start-WUScan
        if ( `$updates ) { 
            `$Job = Install-WUUpdates -Updates `$updates -AsJob
            do { 
                Start-sleep -seconds 30  
            } Until ( (Get-Job `$Job).State
        }
"@



    # ----- Need to run powershell as admin on the VM for the Installl to work
    $CMD = "Start-Process Powershell -Verb RunAs -ArgumentList '-Command `"$UpdateCMD`"'"
    Invoke-VMScript -VM $VM -ScriptText $Cmd -GuestCredential $GuestCredential

    Try {
        # ----- Restart to finish installs
        Restart-VMGuest -VM $VM -ErrorAction Stop | write-Verbose

        Wait-VMState -VM $VM -State PoweredON -ErrorAction Stop 
    
        # ----- Pause after restart to let things settle
        Start-Sleep -Seconds 300

        # ----- Shut down the VM
        Shutdown-VMGuest -vm $VM -Confirm:$False -ErrorAction Stop | Write-Verbose

        Wait-VMState -VM $VM -State PoweredOff -ErrorAction Stop 

        # ----- Convert to Template
        Set-VM -VM $VM -ToTemplate -Confirm:$False -ErrorAction Stop | Write-Verbose
    }
    Catch {
            $ExceptionMessage = $_.Exception.Message
            $ExceptionType = $_.Exception.GetType().Fullname
            Throw "Update-VMwareVMTemplate : There was a problem shutting down VM and Converting it to a template.`n`n     $ExceptionMessage`n`n $ExceptionType"
        }
}