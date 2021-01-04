Function Update-VMWareVMTemplate {

<#
    .SYNOPSIS
        Install patches on VMware Template.

    .DESCRIPTION
        Installs patches.  Currently only works with WIndows patches.

    .PARAMETER Template
        Template object.  Use Get-Template

    .PARAMETER WaitHours
        Number of hours to wait while patches are installed before converting back to templates.

    .PARAMETER VMToolsTimeout
        How long to wait until the VMTools are running.  This prevents a 'hung' script.

    .EXAMPLE
        Install Updates on templates. and wait 24 hours to install patches.

        Get-Template | Update-VMWareVMTemplate -verbose

    .EXAMPLE
        Install Updates on templates. and wait 12 hours to install patches.

        Get-Template | Update-VMWareVMTemplate -WaitHours 12 -verbose

    .NOTES
        Author : Jeff Buenting
        Date : 2020 DEC 24 (Merry Christmas)
#>

    [CmdletBinding()]
    Param (
        [Parameter (Mandatory = $True,ValueFromPipeline = $True) ]
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.TemplateImpl[]]$Template,

        [Decimal]$WaitHours = 24,

        [Int]$VMToolsTimeout = 300
    )
    
    Begin {
        $VMTemplates = @()
    }

    Process {
        # ----- Gather all Templates to run in parallel
        Foreach ( $T in $Template ) {
            $VMTemplates += $T
        }

    }

    End {
        Try {
            # ----- Convert Template to VM
            Set-Template -Template $VMTemplates -ToVM | Write-Verbose
 
            $VM = Get-VM -Name $VMTemplates.Name 
 
            Start-VM -VM $VM | write-Verbose

            Write-Verbose "VMs started, waiting for VMware Tools"
            Wait-Tools -VM $VM -TimeoutSeconds $VMToolsTimeout -ErrorAction Stop | write-Verbose
        }
        Catch {
            $ExceptionMessage = $_.Exception.Message
            $ExceptionType = $_.Exception.GetType().Fullname
            Throw "Update-VMwareVMTemplate : Error converting to VM or Starting VM.`n`n     $ExceptionMessage`n`n $ExceptionType"
        }
 
        # ----- Wait X amount of time for Patches to be applied
        Write-Verbose "Waiting for $($WaitHours*60*60) Seconds for Patching"
        Start-Sleep -Seconds ($WaitHours * 60 * 60)
 
        Try {
            # ----- problems restarting VM.  Turns out you have to get the VM object again.
            $VM = Get-VM -Name $VMTemplates.Name

            # ----- Shut down the VM
            $VM | foreach { 
                $_.Name
                '+'
                Shutdown-VMGuest -VM $_ -Confirm:$False | Write-Verbose
                "-----"
            }

            Wait-VMState -VM $VM -State PoweredOff -ErrorAction Stop 

            # ----- Again issues with working with the VM unless we reget.
            $VM = Get-VM -Name $VMTemplates.Name

            # ----- Convert to Template
            Write-Verbose "Converting to Template"
            $VM | Set-VM -ToTemplate -Confirm:$False | Write-Verbose
        }
        Catch {
            $ExceptionMessage = $_.Exception.Message
            $ExceptionType = $_.Exception.GetType().Fullname
            Throw "Update-VMwareVMTemplate : Error shutting down VM or converting to Template.`n`n     $ExceptionMessage`n`n $ExceptionType"
        }
    }
}