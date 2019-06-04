Configuration RemoteDesktopGateway
{
    param(
        [Parameter(Mandatory=$true)]
        [string]$FQDN
    )
    $VerbosePreference = "Continue"
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -Name WindowsFeature
    Import-DscResource -Name Script
    Node localhost
    {
        File LoggingDirectory # Create a directory for log files and for the cert
        {
            Ensure = "Present"
            DestinationPath = "C:\Temp"
            Type = "Directory"
            MatchSource = $false # Only create the temp directory the first time the configuration is run
        }
        WindowsFeatureSet InstallRemoteDesktopGatewayFeatures
        {
            #Name =  @("web-server", "NPAS-Policy-Server", "Web-ISAPI-Ext", "Web-Mgmt-Compat", "RSAT-NPAS", "RPC-over-HTTP-Proxy", "RSAT-RDS-Gateway", "RDS-Gateway", "Telnet-client")
			Name =  @("web-server", "Web-ISAPI-Ext", "Web-Mgmt-Compat", "RSAT-NPAS", "RPC-over-HTTP-Proxy", "RSAT-RDS-Gateway", "RDS-Gateway", "Telnet-client")
            Ensure =  "Present"
            DependsOn = "[File]LoggingDirectory"
        }
        File FQDNFile
        {
            # Because the DSC Script resources does _not_ accept parameters in its GetScript statement, we will write the compile-time
            #   FQDN parm to disk on this node and read it in in the Script resource below
            DependsOn ="[File]LoggingDirectory"
            Ensure = "Present"
            Type = "File"
            Contents = $FQDN
            DestinationPath = "C:\Temp\FQDN.txt"
        }
        Script "ConfigureRemoteDesktopGateway"
        {
            DependsOn = @("[WindowsFeatureSet]InstallRemoteDesktopGatewayFeatures", "[File]LoggingDirectory")
            SetScript = { # Returns nothing
                Start-Transcript -Path "C:\Temp\ConfigureRemoteDesktopGateway.txt" -Append -Force -IncludeInvocationHeader
                Import-Module RemoteDesktopServices
                # Get the FQDN from the file created in the File resource
                # Create a self-signed certificate. This MUST installed in the LocalMachine Trusted Root store for RDP clients to see it.
                $DomainName = Get-Content -Path "C:\Temp\FQDN.txt" -Raw 
                $x509Obj = New-SelfSignedCertificate -CertStoreLocation Cert:\LocalMachine\My -DnsName $DomainName
                # Export the cert to the desktop for use on clients
                $x509Obj | Export-Certificate -FilePath "C:\Temp\$DomainName.cer" -Force -Type CERT
                # See https://blogs.technet.microsoft.com/ptsblog/2011/12/09/extending-remote-desktop-services-using-powershell-part-5/
                #   for details of using the RDS provider. Its very poorly documented. If you need to find additional items, sl to the GatewayServer location you are interested in
                #   and gci . -recurse | fl
                # Create RD-CAP with two user groups; defaults permit all device redirection. Might be worth tightening up in terms of security.
                $capName = "RD-CAP-$(Get-Date -Format FileDateTimeUniversal)"
                Set-Location RDS:\GatewayServer\SSLCertificate #Change to location where self-signed certificate is specified
                Set-Item .\Thumbprint -Value $x509obj.Thumbprint # Update RDG with the thumprint of the self-signed cert.
                # Create a new Connection Authorization Profile
                New-Item -Path RDS:\GatewayServer\CAP -Name $capName -UserGroups @("administrators@BUILTIN"; "Remote Desktop Users@BUILTIN") -AuthMethod 1
                # Create a new Resouce Authorization Profile with "ComputerGroupType" set to 2 to permit connections to any device
                $rapName = "RD-RAP-$(Get-Date -Format FileDateTimeUniversal)"
                New-Item -Path RDS:\GatewayServer\RAP -Name $rapName -UserGroups @("administrators@BUILTIN"; "Remote Desktop Users@BUILTIN") -ComputerGroupType 2
                Restart-Service TSGateway # We are done; Put everything into effect
                Stop-Transcript
            }
            GetScript = { # Must return a hashtable with at least one key
                Import-Module RemoteDesktopServices
                Return @{ Result = [string]$(Get-ChildItem -name RDS:\GatewayServer\SSLCertificate\Thumbprint) }
            }
            TestScript = { # Must return a boolean: $true or $false
                Import-Module RemoteDesktopServices
                If ((Get-ChildItem RDS:\GatewayServer\SSLCertificate\Thumbprint\).CurrentValue -eq "NULL") # There is no cert stored yet
                {
                    Return $false # The script has not run yet
                }
                Else
                {
                    Return $true # We have previously run this script
                }
            }
        }
    }
}