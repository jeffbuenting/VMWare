Function Wait-VMState {

    [CmdletBinding()]
    Param ( 
        [Parameter (Mandatory = $True) ]
        [VMware.VimAutomation.ViCore.Impl.V1.VM.UniversalVirtualMachineImpl]$VM,

        [Parameter (Mandatory = $True) ]
        [ValidateSet ('PoweredON','PoweredOff')]
        [String]$State,

        [int]$TimeoutSec = 300
    )

    $timer = [Diagnostics.Stopwatch]::StartNew()

    Do {
        Write-Verbose "Waiting for VM to $State ..."
        Start-Sleep -Seconds 15
        
        $VM = Get-VM -Name $VM.Name

    } Until ( ( $VM.PowerState -ne $State ) -and ($timer.Elapsed.TotalSeconds -lt $TimeoutSec) )

    if ( $Timer.Elapsed.TotalSeconds -ge $TimeoutSec ) {
        Throw "Wait-VMState : Error waiting for VM to $State"
    }

    Write-Verbose $State
}

