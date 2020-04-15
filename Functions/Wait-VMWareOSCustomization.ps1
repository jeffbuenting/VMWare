function Wait-VMWareOSCustomization {

<#
    .SYSNOPSIS
        Pauses execution until the OS Customizations have completed.

    .DESCRIPTION
        When using Powershell to create new VMware VMs and applying an OS Customization, the customization does not get applied until after the VM starts.  It make take awhile depending on the configuration.
        To prevent powershell from moving on and potentionally causing issues, you need to wait for the customization to finish.

    .PARAMETER VM
        VM the OS Customizations are being applied.

    .PARAMETER Timeout
        Timeout failsafe.

    .Example
        $VM = New-VM -Name ServerA -Template OSTemplate -OSCustomizationSpec 'WIN 2016 Sysprep'
        $VM = Start-VM -VM $VM
        Wait-VMWareOSCustomization -VM $VM

    .NOTE
        I got this from someone else.  Unfortunately I did not capture the link.  All credit to them.  I just updated this to work with the newer versions of PowerCLI.
    
#>
 

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True)]
        [Vmware.VIMAutomation.ViCore.Types.V1.Inventory.VirtualMachine]$VM,
        
        [Int]$Timeout = 600,

        [Switch]$Retry
    )

    # ----- Check if VM is running
    if ( $VM.PowerState -Ne 'PoweredOn' ) {
        Throw "Wait-VMWareOSCustomization : VM is not running."
    }

    $Timer = [Diagnostics.Stopwatch]::StartNew()

    # wait until customization process has started    
    Write-Verbose "Waiting for OS Customization to start ..."

    Do {
        $vmEvents = Get-VIEvent -Entity $vm -Verbose:$False
        $startedEvent = $vmEvents | Where { $_.GetType().Name -eq "CustomizationStartedEvent" }           
        
        Start-Sleep -Seconds 2
        
        Write-Verbose "Elapsed Time = $($Timer.Elapsed.TotalSeconds)"

        # ----- Check for timeout
        if ( $Timer.Elapsed.TotalSeconds -gt $Timeout ) {
            $Timer.Stop()

            Throw "Wait-VMWareOSCustomization : Timeout waiting for customizations to start"

        }
            
        Write-Verbose "Still waiting for OS Customization to begin ..."
    } Until ( $startedEvent )

    Write-Verbose "OS Customization has begun.  Event = $($startedEvent | Out-String)"
    Write-Verbose "Number of started events = $($startedEvent.count())"

    # ----- I have seen where the OS customization starts multiple times.  If this happens it will never complete.  Work around is to reboot and the customizations starts correctly.
    if ( $Retry -and ($startedEvent.count() -ge 2)) {
        Write-Verbose "The OS Customization started multiple times.  Retry setting is true.  Rebooting computer to continue."

        Restart-VM -VM $VM | Wait-Tools 

        # ----- Restart Timer, clear startedevent and Continue
        $startedEvent = $Null

        $Timer = [Diagnostics.Stopwatch]::StartNew()
    }

    # wait until customization process has completed or failed
    Write-Verbose "Waiting for customization to complete ..."

    Do {
        $vmEvents = Get-VIEvent -Entity $vm -Verbose:$False
        $succeedEvent = $vmEvents | Where { $_.GetType().Name -eq "CustomizationSucceeded" }
        $failEvent = $vmEvents | Where { $_.GetType().Name -eq "CustomizationFailed" }

        Write-Debug "SucceedEvent = $($succeedEvent | out-string)"
        Write-Debug "FailEvent = $($failEvent | out-string)"
                
        if ($failEvent) {
            $Timer.Stop()

            Throw "Wait-VMWareOSCustomization : OS Customization Failed."
        }
        
        Start-Sleep -Seconds 2  
        
        Write-Verbose "Elapsed Time = $($Timer.Elapsed.TotalSeconds)"                                   

        # ----- Check for timeout
        if ( $Timer.Elapsed.TotalSeconds -gt $Timeout ) {
            $Timer.Stop()

            Throw "Wait-VMWareOSCustomization : Timeout waiting for customizations to start"
        }

        Write-Verbose "Still waiting for OS Customization to complete..."
    } Until ($succeedEvent)
    
    Write-Verbose "Customization Succeeded.  SucceedEvent = $($succeedEvent | out-string)"

    $Timer.Stop()
}

 