#[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls, 
#[Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls12, 
#[Net.SecurityProtocolType]::Ssl3
#[Net.ServicePointManager]::SecurityProtocol = "Tls, Tls11, Tls12, Ssl3"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls13

$registryPath = "HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319"

$Name = "SchUseStrongCrypto"

$value = "1"

IF(!(Test-Path $registryPath))

  {

    New-Item -Path $registryPath -Force | Out-Null

    New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null}

 ELSE {

    New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null}


# Restart the remote machine
Restart-Computer -Force
# Wait for the machine to come back online
Write-Host "Waiting for $computerName to come back online..."
# Use Test-Connection to check if the remote machine is online
while (-not (Test-Connection -ComputerName $computerName -Count 1 -Quiet)) {
    Start-Sleep -Seconds 300  # Wait for 300 seconds before checking again
}

Write-Host "$env:COMPUTERNAME is back online."

param (
    [Parameter(Mandatory)]
    [string]$domain,

    [Parameter(Mandatory)]
    [string]$password

)

$ErrorActionPreference = "Stop"

$completeFile="c:\temp\prereqsComplete"
if (!(Test-Path -Path "c:\temp")) {
    mkdir "c:\temp"
}

$step=1
if (!(Test-Path -Path "$($completeFile)$step")) {
    # Shortcuts
	if (!(Test-Path -Path "c:\AADLab")) {
		mkdir "c:\AADLab" -ErrorAction Ignore
	}

	$WshShell = New-Object -comObject WScript.Shell
	$dt="C:\Users\Public\Desktop\"
	$ieicon="%ProgramFiles%\Internet Explorer\iexplore.exe, 0"

	$links = @(
		@{site="https://connect.microsoft.com/site1164";name="Azure AD Connect Home";icon=$ieicon},
		@{site="https://docs.microsoft.com/en-us/azure/active-directory/connect/active-directory-aadconnect";name="Azure AD Docs";icon=$ieicon},
		@{site="https://connect.microsoft.com/site1164/Downloads/DownloadDetails.aspx?DownloadID=59185";name="Download Azure AD Powershell";icon=$ieicon},
		@{site="%windir%\system32\WindowsPowerShell\v1.0\PowerShell_ISE.exe";name="PowerShell ISE";icon="%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell_ise.exe, 0"},
		@{site="%SystemRoot%\system32\dsa.msc";name="AD Users and Computers";icon="%SystemRoot%\system32\dsadmin.dll, 0"},
		@{site="%SystemRoot%\system32\domain.msc";name="AD Domains and Trusts";icon="%SystemRoot%\system32\domadmin.dll, 0"},
		@{site="%SystemRoot%\system32\dnsmgmt.msc";name="DNS";icon="%SystemRoot%\system32\dnsmgr.dll, 0"},
		@{site="%windir%\system32\services.msc";name="Services";icon="%windir%\system32\filemgmt.dll, 0"},
		@{site="c:\AADLab";name="AAD Lab Files";icon="%windir%\explorer.exe, 13"}
	)

	foreach($link in $links){
		$Shortcut = $WshShell.CreateShortcut("$($dt)$($link.name).lnk")
		$Shortcut.TargetPath = $link.site
		$Shortcut.IconLocation = $link.icon
		$Shortcut.Save()
	}

    #record that we got this far
    New-Item -ItemType file "$($completeFile)$step"
}

$step=2
if (!(Test-Path -Path "$($completeFile)$step")) {
    $smPassword = (ConvertTo-SecureString $password -AsPlainText -Force)

    #Install AD, reconfig network
    Install-WindowsFeature -Name "AD-Domain-Services" `
                           -IncludeManagementTools `
                           -IncludeAllSubFeature 

    Install-ADDSForest -DomainName $domain `
                       -DomainMode Win2016 `
                       -ForestMode Win2016 `
                       -Force `
                       -SafeModeAdministratorPassword $smPassword 

    #record that we got this far
    New-Item -ItemType file "$($completeFile)$step"
}

$step=3
if (!(Test-Path -Path "$($completeFile)$step")) {
    $Dns = "127.0.0.1"
    $IPType = "IPv4"

    # Retrieve the network adapter that you want to configure
    $adapter = Get-NetAdapter | Where-Object {$_.Status -eq "up"}
    $cfg = ($adapter | Get-NetIPConfiguration)
    $IP = $cfg.IPv4Address.IPAddress
    $Gateway = $cfg.IPv4DefaultGateway.NextHop
    $MaskBits = $cfg.IPv4Address.PrefixLength

    # Remove any existing IP, gateway from our ipv4 adapter
    If (($adapter | Get-NetIPConfiguration).IPv4Address.IPAddress) {
        $adapter | Remove-NetIPAddress -AddressFamily $IPType -Confirm:$false
    }

    If (($adapter | Get-NetIPConfiguration).Ipv4DefaultGateway) {
        $adapter | Remove-NetRoute -AddressFamily $IPType -Confirm:$false
    }

    #record that we got this far
    New-Item -ItemType file "$($completeFile)$step"
}

$step=4
if (!(Test-Path -Path "$($completeFile)$step")) {
    # Configure the IP address and default gateway
    $adapter | New-NetIPAddress `
        -AddressFamily $IPType `
        -IPAddress $IP `
        -PrefixLength $MaskBits `
        -DefaultGateway $Gateway

    # Configure the DNS client server IP addresses
    $adapter | Set-DnsClientServerAddress -ServerAddresses $DNS

    #record that we got this far
    New-Item -ItemType file "$($completeFile)$step"
}

