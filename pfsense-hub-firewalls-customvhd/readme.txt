Hyper-V custom pfSense VHD build
--------------------------------

VSwitch
-External on Wifi adapter in Hyper-V host

Create hard disk
-VHD
-Fixed Size
-32 GB

Create VM
-Generation 1
-4096 MB, not dynamic
-Connection to External
-2 vCPU
-32GB
-mount ISO
-Use existing hard disk

Edit VM
-add second NIC to External

Install pfSense
-accept all defaults
-Reboot and eject media
-no VLANs
-hn0 WAN
-hn1 LAN

2. Select 2 for LAN
192.168.1.200
24
No gateway or IPv6
No DHCP server
No webConfigurator

8. Shell 
pkg upgrade
pkg install -y sudo bash git
ln -s /usr/local/bin/python2.7 /usr/local/bin/python

# Clone the Git repository
git clone https://github.com/Azure/WALinuxAgent.git
# Enter the WALinuxAgent directory
cd WALinuxAgent
# List all available versions
git tag
# Checkout the latest (stable) version of the agent
git checkout v2.2.34
# Install the agent
python setup.py install

ln -sf /usr/local/sbin/waagent /usr/sbin/waagent


Configure LAN interface as DHCP
Browse to https://192.168.1.200
Disable Block private networks from entering via WAN
Complete setup
Edit Interface LAN, set to DHCP, Apply Changes!
Diagnostics > Halt System

Power off VM.
Upload VHD to storage account


