# --- New Basic Windows Server OS Initial Configuration ---
# Created by Hargie J. Curato
# Created date: 03/21/2025

# -- Prerequisites ---
# -- If run on a VMWare's Virtual Machine, install the VMWare Tools first.

# -- Start --
Clear-Host

# 00. Set Variables for Network Address Configuration
# Define network settings (Change these values, depends on your network settings)
$ip = "192.168.100.95"				#Replace the string of the actual primary IP address.
$pref = 24           				#Replace the string of the actual subnet mask
$gw = "192.168.100.1"				#Replace the string of the actual Default Gateway address.
$dns1 = "192.168.100.1"				#Replace the string of the actual primary dns address.
$dns2 = "8.8.8.8"                   #Replace the string of the actual secondary dns address
$tz = "China Standard Time"			#Replace the string with the preferred Timezone. 
$sp = "m:\sources\sxs"				#Source path in order to install .NetFramework
$nm = "AD-demo2019"					#Replace with the preferred Computer name.

Clear-Host
# High Performance power plan GUID
$HighPerformanceGUID = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"

# Set the High Performance power plan as active
powercfg /setactive $HighPerformanceGUID

# Optional: Verify the active power plan
$pplan = powercfg /getactivescheme
Write-Host $pplan -ForegroundColor Green

# Enable Remote Desktop
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0

# Disable Network Level Authentication (NLA) [Optional]. Uncomment the below commands if needed
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 0

# Enable the Remote Desktop firewall rule
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
Write-Host "Remote Desktop with unchecked NLA is done" -Foreground Green

# Import the Storage module
Import-Module Storage

# Set CD/DVD Drive to M
Get-WmiObject -Class Win32_volume -Filter 'DriveType=5' | Select-Object -First 1 | Set-WmiInstance -Arguments @{DriveLetter='M:'}

# Rename the volume on the C: drive
$label = "SYSTEM"
Set-Volume -DriveLetter C -NewFileSystemLabel $label

# Verify the change
Get-Volume -DriveLetter C
Write-Host "Disk Drive letter was changed to M" -Foreground Green

# Define the ports for Active Directory Domain Services & SQL Server (Optional, comment out these whole lines, if you don't need it)
# You can add Ports Rule as much as you want, just copy the line that start at @{ and end with }. If you add multiple lines, do not forget to add (,).
$ports = @(
    @{ Protocol = "TCP"; LocalPort = 53; Name = "DNS (TCP)" },
    @{ Protocol = "UDP"; LocalPort = 53; Name = "DNS (UDP)" },
    @{ Protocol = "TCP"; LocalPort = 88; Name = "Kerberos (TCP)" },
    @{ Protocol = "UDP"; LocalPort = 88; Name = "Kerberos (UDP)" },
    @{ Protocol = "TCP"; LocalPort = 389; Name = "LDAP (TCP)" },
    @{ Protocol = "UDP"; LocalPort = 389; Name = "LDAP (UDP)" },
    @{ Protocol = "TCP"; LocalPort = 636; Name = "LDAPS (TCP)" },
    @{ Protocol = "TCP"; LocalPort = 445; Name = "SMB (TCP)" },
    @{ Protocol = "TCP"; LocalPort = 135; Name = "RPC Endpoint Mapper (TCP)" },
    @{ Protocol = "TCP"; LocalPort = "49152-65535"; Name = "Dynamic RPC (TCP)" },
    @{ Protocol = "UDP"; LocalPort = 137; Name = "NetBIOS Name Service (UDP)" },
    @{ Protocol = "UDP"; LocalPort = 138; Name = "NetBIOS Datagram Service (UDP)" },
    @{ Protocol = "TCP"; LocalPort = 139; Name = "NetBIOS Session Service (TCP)" },
    @{ Protocol = "TCP"; LocalPort = 3268; Name = "Global Catalog LDAP (TCP)" },
    @{ Protocol = "TCP"; LocalPort = 3269; Name = "Global Catalog LDAPS (TCP)" },
    @{ Protocol = "TCP"; LocalPort = 464; Name = "Kerberos Password Change (TCP)" }
    #SQL Server port should only be added if the server is hosting SQL Server - Comment out this line.
    #@{ Protocol = "TCP"; LocalPort = 1433; Name = "SQL Server (TCP)" }
)

# Function to create firewall rules
function CreateFirewallRules {
    param (
        [string]$direction
    )

    foreach ($port in $ports) {
        try {
            New-NetFirewallRule -DisplayName "AD DS $direction - $($port.Name)" -Direction $direction -Protocol $($port.Protocol) -LocalPort $($port.LocalPort) -Action Allow -Profile Domain,Private
            Write-Host "Firewall rule 'AD DS $direction - $($port.Name)' created successfully."
        } catch {
            Write-Error "Failed to create firewall rule 'AD DS $direction - $($port.Name)': $($_.Exception.Message)"
        }
    }
}

# Create inbound and outbound rules
CreateFirewallRules -direction Inbound
CreateFirewallRules -direction Outbound

Write-Host "AD DS firewall rules creation completed."
Write-Host "AD DS firewall & SQL Server rules created."

# Verify the added Rules
Get-NetFirewallRule | Format-Table DisplayName, Enabled, Profile, Direction, LocalPort
Write-Host "Ports & Rules are added" -ForegroundColor Green

#Get Network Interface Name (Assuming that your default LAN interface has "Ethernet" on its name, which is the usual default LAN interface name for Windows Server).
$EthernetAdapters = Get-NetAdapter | Where-Object {$_.Name -like "*Ethernet*"} | Select-Object -ExpandProperty Name

# Define network settings (Change these values, depends on your network settings)
$InterfaceAlias = $EthernetAdapters
$IPAddress = $ip
$PrefixLength = $pref
$DefaultGateway = $gw
$PrimaryDNS = $dns1
$SecondaryDNS = $dns2

# Set the IP address and subnet mask
New-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress $IPAddress -PrefixLength $PrefixLength -DefaultGateway $DefaultGateway

# Set the DNS servers
Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $PrimaryDNS, $SecondaryDNS
Clear-DnsClientCache
Register-DnsClient

# Verify the configuration
Get-NetIPAddress -InterfaceAlias $InterfaceAlias
Get-DnsClientServerAddress -InterfaceAlias $InterfaceAlias

# Set the time zone to match Philippine Standard Time (Change the value of $timezone based on actual path of the source)
$timezone = "China Standard Time"
Set-TimeZone -Name $timezone

# Verify the current time zone
Get-TimeZone

# Install .NET Framework 3.5 from the specified source (Change the value of $sourcePath based on actual path of the source)
$sourcePath = $sp
Install-WindowsFeature Net-Framework-Core -Source $sourcePath

# Verify the installation
Get-WindowsFeature -Name Net-Framework*

# Rename the computer (Change the value of $newname based on your preferred computer name)
$newname = $nm
Rename-Computer -NewName $newname -Force

# Restart the computer for the changes to take effect
$response = Read-Host -Prompt "Basic Windows Server OS Initial Configuration completed. Do you want to restart the computer now? (Y/N)"
if ($response -eq "Y") {
    Restart-Computer
} else {
    Write-Host "Restart skipped. Please remember to manually restart the computer later." -ForegroundColor Yellow
}

