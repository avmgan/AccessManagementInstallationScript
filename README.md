# Access Management Install

This is my first attempt to create an "all-in-one" installer for people that don't want to be bothered following setup instructions from Tridion Sites documentation to setup Access Management through UI Interface

# Pre-Requisites

To use this script, you need:

* SDL Tridion 9.5 Installer
* Any Database version that is supported by Content Manager and Content Delivery
* Any Microsoft Windows server operating system that is supported for Content Manager server or Content Delivery server
* .NET Core and ASP.NET Core host bundles version 3.1
* .PFX  signed certificate either issued from a certificate authority (CA) or self-signed

# Instructions

Edit the file "Install-Options.ps1" and modify it to fit your needs. At a minimum, you need to specify valid Access Management database and credentials.

Run the AccessManagement-Service-Install.ps1 script (as Administrator) to launch the AM installation process to install and configure.

.EXAMPLE1
   .\AccessManagement-Service-Install.ps1 -TCMInstallerPath D:\_Install\TridionSites95 -InstallationDir "D:\TXS2020-DEMO\Access Management" -CertThumbprint "4af0b42497e5988df2235b65ede11742e503fecd"

.EXAMPLE2
   .\AccessManagement-Service-Install.ps1 -TCMInstallerPath D:\_Install\TridionSites95 -InstallationDir "D:\TXS2020-DEMO\Access Management" -CertThumbprint "4af0b42497e5988df2235b65ede11742e503fecd" -SkipDBCreation   

# What do you get?

This will:
* Create Access Managenemtn database
* Export PFX Certificae
* Install SDL Tridion Access Management Service and Configure idp provider

At the end of the script you get:
* Access Management running on port 84

# Bugs
I still want to make it more robust and configurable (especially for distributed environments) and iron out some quirks.
