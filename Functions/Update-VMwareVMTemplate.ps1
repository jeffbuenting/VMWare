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
        [PSCredential]$GuestCredential,
        
        [Parameter (Mandatory = $True) ]
        [String]$RemoteLog,

        [Int]$TimeoutSec = 3600
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
# ----- Is the PSWindowsUpdate module there?
    $CreateScript =  @"
        `$UpdateCMD = @'
            Out-File -FilePath $RemotePath\TemplateUpdate.log -InputObject "--------------------------" -Append



            if ( -Not ( Get-Module -ListAvailable -Name PSWindowsUPdate ) ) {
                Out-File -FilePath $RemotePath\TemplateUpdate.log -InputObject "`$(Get-Date -Format G) - Start-OSUpdate : Error : PSWindowsUpdate is required." -Append
                Throw "Start-OSUpdate : PSWindowsUpdate is required."
            }
            Else {
                Out-File -FilePath $RemotePath\TemplateUpdate.log -InputObject "`$(Get-Date -Format G) - Importing PSWIndowsUpdate Module." -Append
                Import-module PSWindowsUpdate
            }

            Try {
                `$Updates = Get-WUList -ErrorAction Stop
                Out-File -FilePath $RemotePath\TemplateUpdate.log -InputObject "`$(Get-Date -Format G) - ``n`$(`$Updates | Out-string)." -Append
                `$Updates | Install-WindowsUpdate -AutoReboot -Confirm $False -ErrorAction Stop
            }
            Catch {
                `$ExceptionMessage = `$_.Exception.Message
                `$ExceptionType = `$_.Exception.GetType().Fullname
                Out-File -FilePath $RemotePath\TemplateUpdate.log -InputObject "`$(Get-Date -Format G) - Start-OSUpdate : Error : Getting or Installing Updates.``n``n     `$ExceptionMessage``n``n `$ExceptionType" -Append
            }
'@
        `$UpdateCmd | out-file $RemotePath\Start-OSUpdate.ps1 -Append
"@

Invoke-VMScript -VM $VM -ScriptText $CreateScript -GuestCredential $GuestCredential


    $CMD = @"
        Start-Process C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Verb Runas -argumentList "-ExecutionPolicy Bypass -File $RemotePath\Start-OSUpdate.ps1"
"@

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