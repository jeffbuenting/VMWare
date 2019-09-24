Function Check-alignment{
<#
	.Synopsis
	This function remotely checks a VM guest for mis-alignment
	
	.Description
	This  fuction uses a wmi query against a remote machine. From the wmi query, it does a little math to determine if the remote machine is aligned or not. For any computers it has issues connecting to, it will report that as well.
	
	.Parameter Offset
	By default this is set to 1024. Which I believe is a pretty standard offset for storage providers.
	
	.Parameter Computernames
	The list of computers/vms whose alignment you want to check. Again by default it will grab the VMs of you currently connected vCenter.
	
	.Example
	
	Check-Alignment
	
	With no parameters used, it will check the alignment of all currently turned on VMs which belong to your currently connected vCenter. 
	
	.Example
	
	Check-alignment -computernames myvm -offset 3243
	
	Check the computer "myvm" for the offset of 3243
	
	.Link
	www.vnoob.com
	
	./Notes
	
	
	

====================================================================
	Author:
	Conrad Ramos <conrad@vnoob.com> http://www.vnoob.com/

	Date:			2012-10-23
	Revision: 		1.0
	
	Disclaimer:
	Not that I think anything bad could happen, but I am not responsible for any use or misuse of this function. :)
	
	
====================================================================


#>

param($offset=1024, $computernames=$null)

$output=@()

If ($computernames -eq $null)
{
$computernames=Get-vm * | ?{$_.powerstate -like "*on"} | Where-Object {$_.name -notlike $null} |select -expand name
}


$disks=get-wmiobject -computername $computernames -class win32_diskpartition -erroraction silentlycontinue


ForEach ($disk in $disks)



{
$aligned=$null
IF(($disk.startingoffset % $offset) -eq 0){$aligned="DiskAligned"}
Else{$aligned="NotAligned"}

$disk |add-member noteproperty DesiredOffset ("$offset")
$disk |add-member noteproperty Aligned ("$aligned")
}

Write-Output "The following could not be reached:"
 Compare-Object $computernames  ($disks.pscomputername|get-unique)|select -expand inputobject|Format-Wide

Write-Output "Alignment Report:"
$disks |sort-object |select-object Systemname, startingoffset,desiredoffset,index,aligned 
 }
