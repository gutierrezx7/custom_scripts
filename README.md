# Custom Scripts

This repository contains custom utility scripts.

## DynFi Manager Installer

### Description
`DynFi_Manager_installer.sh` is an installation script for DynFi Manager that supports:
- **Ubuntu** 16.04 (Xenial), 18.04 (Bionic), 20.04 (Focal), 22.04 (Jammy), and newer versions
- **Debian** 9 (Stretch), 10 (Buster), 11 (Bullseye), 12 (Bookworm), and newer versions
- **macOS** (with Homebrew)

### Features
- Automated installation of OpenJDK 11 JRE
- MongoDB installation with version selection based on OS
- DynFi Manager installation and configuration
- Uninstall support for all components
- Interactive prompts for customization

### Usage

#### Installation
Run as root:
```bash
sudo ./DynFi_Manager_installer.sh
```

#### Force installation for a specific distribution:
```bash
sudo ./DynFi_Manager_installer.sh -d <distro>
```
Where `<distro>` can be: `ubuntu`, `debian`, or `macos`

#### Uninstall:
```bash
sudo ./DynFi_Manager_installer.sh -u
```

### Requirements
- Root/sudo access
- Internet connection for downloading packages
- Supported operating system

### License
GNU GPL v3.0 - See LICENSE file for details

Copyright (c) 2022 Kevin HUART for DynFi  
Copyright (c) 2023 Gregory BERNARD for DynFi