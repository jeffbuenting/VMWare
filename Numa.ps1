Function Get-VMWareVMNuma {

<#
    .SYNOPSIS
        Calculates VM NUMA Configuration and wether it is optimal or not.

    .NOTES
        Optimal = Fits in NUMA node or spans evenly between multiple NUMA nodes

#>

    [CmdletBinding()]
    Param (
        [Parameter (Mandatory = $True, ValueFromPipeline = $True)]
        $VM
    )

    Process {
        Foreach ( $V in $VM ) {
            Write-Verbose "Calculating Numa Info for VM : $($V.Name)"
            # ----- Calculate VM's Host
            $HostView = Get-View -VIObject ( Get-VMHost $V.VMHost )

            # ----- Get Host Numa Node Size
            $CPUNumaNodes = $HostView.hardware.NumaInfo.NumNodes
            $CPUPerNode = $HostView.Hardware.CPUInfo.NumCPUCores / $CPUNumaNodes

            $MemNumaperNode = ([math]::Round($HostView.Hardware.MemorySize / 1GB)) / $CPUNumaNodes

            # ----- Calculate VM Numa Status
            $VMNuma = [PSCustomObject]@{
                Name = $V.Name
                Host = $HostView.Name
                HostNumaNodes = $CPUNumaNodes
                HostNumaCPUCoresPerNode = $CPUPerNode
                HostNumaMEMPerNode = $MemNumaperNode
                CPUSockets = $V.NumCPU / $V.CoresPerSocket
                NumCPUperSocket = $V.CoresPerSocket
                MemoryGB = $V.MemoryGB
                NumaStatus = $( 
                    if ( ( $V.CoresPerSocket -le $CPUPerNode ) -and ( $V.MemoryGB -le $MemNumaperNode ) )  {
                        'Optimized'
                    }
                    Else {
                        
                        'Warning'
                    }
                )
            }

            Write-Output $VMNuma
        }
    }

}


Get-vm nmcpeh-xfr | Get-VMWareVMNuma -Verbose | FT * -AutoSize