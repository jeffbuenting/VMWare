# VMWare
VMWare powershell module

### Master

Version: 1.0.5

[![Build status](https://ci.appveyor.com/api/projects/status/v6ex7ak8plsoutn5/branch/master?svg=true)](https://ci.appveyor.com/project/jeffbuenting/vmware/branch/master)


### Functions

**Get-VMWareVMReconfiguration**

  Audit changes made to a virtual machine.  Instead of manually scrolling through the event log in vCenter, this function will get parse the event log for you and out put all changes made to a specific VM.

  *Example*   
    List changes in the month of November for the following vm: Server01

    (Get-VIEvent -Entity Server01) | where { $_.gettype().name -eq 'VmReconfiguredEvent' } | Get-VMWareVMReconfiguration
