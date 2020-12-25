Function Wait-VMState {

    [CmdletBinding()]
    Param ( 
        [Parameter (Mandatory = $True) ]
        [VMware.VimAutomation.ViCore.Impl.V1.VM.UniversalVirtualMachineImpl]$VM,

        [Parameter (Mandatory = $True) ]
        [ValidateSet ('PoweredON','PoweredOff')]
        [String]$State

        
    )

    Do {
        Write-Verbose "Waiting for VM to $State ..."
        Start-Sleep -Seconds 30
        
        $VM = Get-VM -Name $VM.Name

    } While ( $VM.PowerState -ne $State )

    Write-Verbose $State
}

