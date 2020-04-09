function Wait-VMWareOSCustomization {

 

    [CmdletBinding()]

    param (

                    [Parameter(Mandatory=$True)]

                    [Vmware.VIMAutomation.ViCore.Impl.V1.Inventory.VirtualMachineImpl]$VM,

 

        [Int]$Timeout = 600

    )

 

    # ----- Check if VM is running

    if ( $VM.Status -Ne 'Running' ) {

        Throw "Wait-VMWareOSCustomization : VM is not running."

    }

 

    $Timer = [Diagnostics.Stopwatch]::StartNew()

 

                # wait until customization process has started    

                Write-Verbose "Waiting for Customization to start ..."

                Do {

 

                                $vmEvents = Get-VIEvent -Entity $vm

                                $startedEvent = $vmEvents | Where { $_.GetType().Name -eq "CustomizationStartedEvent" }


                                Start-Sleep -Seconds 2

 

        # ----- Check for timeout

        if ( $Timer.Elapsed.TotalSeconds -gt $Timeout ) {

            $Timer.Stop()

            Throw "Wait-VMWareOSCustomization : Timeout waiting for customizations to start"

        }

 

                } Until ( $startedEvent )


                # wait until customization process has completed or failed

                Write-Verbose "Waiting for customization to complete ..."

                Do {

                                $vmEvents = Get-VIEvent -Entity $vm

                                $succeedEvent = $vmEvents | Where { $_.GetType().Name -eq "CustomizationSucceeded" }

                                $failEvent = $vmEvents | Where { $_.GetType().Name -eq "CustomizationFailed" }


                                if ($failEvent) {

                                                $Timer.Stop()

            Throw "Wait-VMWareOSCustomization : OS Customization Failed."

                                }


                                Start-Sleep -Seconds 2                                  

       

        # ----- Check for timeout

        if ( $Timer.Elapsed.TotalSeconds -gt $Timeout ) {

            $Timer.Stop()

            Throw "Wait-VMWareOSCustomization : Timeout waiting for customizations to start"

        }

 

                } Until ($succeedEvent)

 

    Write-Verbose "Customization Succeeded"

 

    $Timer.Stop()

}

 