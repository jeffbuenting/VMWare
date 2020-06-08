#    # ----- VM must be Powered off to change boot order
#    Write-Log -Path "$LogPath\$($VMName).log"  -Message "Shutting down the VM" -Verbose:$IsVerbose
#    Shutdown-VMGuest -VM $VM -Confirm:$False
#
#    $VM = Get-VM -Name $VMName
#
#    # ----- Wait for VM to be powered off.
#    Write-Log -Path "$LogPath\$($VMName).log"  -Message "Waiting until the VM is in a PoweredOff State prior to changing boot order" -Verbose:$IsVerbose
#    while ( $VM.PowerState -ne 'PoweredOff' ) {
#        Start-Sleep -s 5
#        Write-Output "Powerstate = $($VM.Powerstate)"
#        $VM = Get-VM -Name $VMName
#    }
#
#    # ----- Configure VM to Boot from WINPEUIFIConvertion ISO
#        Write-Log -Path "$LogPath\$($VMName).log"  -Message "Setting CDRom as only boot option" -Verbose:$IsVerbose
#
#        # ----- Capture info needed to register vm
#        $VMXPath = $VM.ExtensionData.Config.Files.VmPathName
#        $Folder = $VM.Folder
#        if ( $($VM.ResourcePool) ) {
#            $ResourcePool = $VM.ResourcePool
#        }
#        Else {
#            $ResourcePool = (Get-Cluster -VM $VM).Name
#        }
#
#
#        # ----- Set CDROM as first boot
#        $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
#
#        $BootOptions = New-Object VMware.Vim.VirtualMachineBootOptions
#
#        $BootableCDRom = New-Object -Type VMware.Vim.VirtualMachineBootOptionsBootableCdromDevice
#
#        #$HDiskDeviceName = "Hard disk 1"
#        #$HDiskDeviceKey = ($vm.ExtensionData.Config.Hardware.Device | ?{$_.DeviceInfo.Label -eq $HDiskDeviceName}).Key
#        #$BootableHDisk = New-Object -TypeName VMware.Vim.VirtualMachineBootOptionsBootableDiskDevice -Property @{"DeviceKey" = $HDiskDeviceKey}
#
#        $BootOrder = $BootableCDRom
#
#        $BootOptions.BootOrder = $BootOrder
#
#        $Spec.BootOptions = $BootOptions
#
#        $VM.ExtensionData.reconfigvm( $Spec )
#
#        # ----- Remove and Reregister so VMX changes happen
#        Remove-Inventory -Item $VM -Confirm:$False
#
#        # ----- Register VM (use clustername as the default resourcepool)
#        $VM = New-VM -VMFilePath $VMXPath -Location $Folder -ResourcePool $ResourcePool
#
#
#
#
#
#
#        #    $spec = New-Object VMware.Vim.VirtualMachineConfigSpec 
#        #    $Spec.BootOPtions = New-Object VMware.Vim.VirtualMachineBootOptions 
#        #    $SPec.BootOptions.BootOrder = New-Object -Type VMware.Vim.VirtualMachineBootOptionsBootableCdromDevice
#        #
#        #    ## reconfig the VM to use the spec with the new BootOrder
#        #    $vm.ExtensionData.ReconfigVM_Task($spec)
#
#    # ----- so I am having problem imediately starting the VM.  So pausing for x Seconds
#    Start-Sleep -Seconds 30
#
#    Write-Log -Path "$LogPath\$($VMName).log"  -Message "Booting to WINPE to performing the magic" -Verbose:$IsVerbose
#    Start-VM -vm $VM 