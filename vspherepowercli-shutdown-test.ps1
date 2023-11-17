#Purpose of this script is to send shutdown commands to all VM's on an ESXI server when this script is run or called from another script.
#The current setup is expecting it to be called by a batch or cmd file that uses the following line:
#"%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe" -ExecutionPolicy Unrestricted -NoProfile -NonInteractive <path>\vspherepowercli-shutdown.ps1" >> "<logfilename>"

#txt file with the vm list. Make list manually or use "Get-VM -Name | Format-List" from Connect-VIServer. 
#Make sure the presence servers are in the presence list and not in the regular vm list
#Shutting down the presence servers before the other servers are down causes issues, need to make sure presence servers start up before the others as well
$primary_vm_list = Get-Content C:\Scripts\testscripts\vmlist.txt
$presence_vm_list = Get-Content C:\Scripts\testscripts\presence_vmlist.txt 

#Create the xml file using the following:
# New-VICredentialStoreItem -Host <hostname> -User <username> -Password <pass> -File C:\Scripts\<nameoffile>.xml
$creds = Get-VICredentialStoreItem -file C:\Scripts\vicredentials.xml

#Sets the timeout for server shutdown so that the do while loops don't hang, but start a forced shutdown 
$timeout = New-TimeSpan -Seconds 30
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

#Declare Get Time Stamp Function
function Get-TimeStamp {
    return "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)    
}

#Output for log
Write-Output "$(Get-TimeStamp) - Shutdown Request from APC UPS Sent."

#Connect to the ESXI host
Connect-VIServer -Server $creds.Host -user $creds.User -password $creds.Password

#Runs through the primary vm list and shuts down those servers. The script will verify that they are down after 15 seconds, and move on if they are.
#If they are not down, it will repeat unless the timeout has been reached (currently 30 seconds, need to update before production)
do {
    Shutdown-VMGuest -VM $primary_vm_list -WhatIf # Change to -Confirm:$false when ready for production
    Start-Sleep -Seconds 15
    $results = $primary_vm_List | Test-NetConnection -Port 8443 -InformationLevel Quiet
} while ($results -contains $true -and $stopwatch.elapsed -lt $timeout)

#add -force - Stop-VMGuest if timeout is reached (review before production)

#Output for log
Write-Output "$(Get-TimeStamp) - All VM's except presense servers are shutdown."

#Runs through the presence vm list and shuts down those servers. The script will verify that they are down after 15 seconds, and move on if they are.
#If they are not down, it will repeat unless the timeout has been reached (currently 30 seconds, need to update before production)
do {
    Shutdown-VMGuest -VM $presence_vm_list -WhatIf # Change to -Confirm:$false when ready for production
    Start-Sleep -Seconds 15
    $results = $presence_vm_List | Test-NetConnection -Port 8443 -InformationLevel Quiet
} while ($results -contains $true -and $stopwatch.elapsed -lt $timeout)

#add -force - Stop-VMGuest if timeout is reached (review before production)

#Output for log
Write-Output "$(Get-TimeStamp) - Presence servers are shutdown."

#Disconnect from ESXI
Disconnect-VIServer -Confirm:$false
