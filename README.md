# Custom Scripts

A collection of useful automation scripts for system administration and deployment.

## Scripts

### Wazuh Agent Installation for Proxmox VE

**File:** `wazuh-agent-install.sh`

Automated deployment script for installing and configuring Wazuh Agent 4.14.1 on Proxmox VE hosts with comprehensive monitoring capabilities.

#### Features

- ✅ Complete pre-installation validation (root permissions, OS compatibility, disk space, network connectivity)
- ✅ Automatic repository configuration with GPG key verification
- ✅ Wazuh Agent 4.14.1 installation
- ✅ Proxmox VE-specific monitoring configuration including:
  - System logs (journald)
  - Kernel audit logs
  - Proxmox VE logs (pve, pveproxy, cluster)
  - LXC container logs
  - Package updates (APT history)
  - Authentication logs (SSH, auth.log)
  - Apache logs (if applicable)
  - File Integrity Monitoring (FIM) for critical Proxmox files
  - Rootkit detection
  - System inventory
  - Security Configuration Assessment (SCA)
- ✅ Comprehensive error handling and logging
- ✅ Post-installation validation
- ✅ Detailed installation report

#### Requirements

- **Operating System:** Debian 11/12 or Ubuntu 20.04/22.04
- **Proxmox VE:** Version 7, 8, or 9 (recommended)
- **Privileges:** Root access (sudo)
- **Disk Space:** Minimum 1GB free in `/var`
- **Network:** Internet connectivity and access to Wazuh Manager

#### Usage

```bash
# Basic installation (uses default Wazuh Manager: soc.expertlevel.lan)
sudo ./wazuh-agent-install.sh

# Custom Wazuh Manager
sudo WAZUH_MANAGER="your-manager.domain.com" ./wazuh-agent-install.sh

# Custom Wazuh Manager with custom port
sudo WAZUH_MANAGER="your-manager.domain.com" WAZUH_MANAGER_PORT="1515" ./wazuh-agent-install.sh
```

#### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `WAZUH_MANAGER` | Wazuh Manager hostname or IP | `soc.expertlevel.lan` |
| `WAZUH_MANAGER_PORT` | Wazuh Manager port | `1514` |

#### Installation Phases

1. **Pre-requisite Validation** - Checks system requirements and connectivity
2. **System Update** - Updates package lists and installs dependencies
3. **Repository Setup** - Configures Wazuh repository with GPG key
4. **Agent Installation** - Installs Wazuh Agent package
5. **Agent Configuration** - Applies Proxmox VE-specific monitoring settings
6. **Service Start** - Enables and starts the Wazuh Agent service
7. **Validation** - Verifies successful installation and connectivity

#### Logs and Configuration

- **Installation Log:** `/var/log/wazuh-install.log`
- **Agent Configuration:** `/var/ossec/etc/ossec.conf`
- **Configuration Backups:** `/var/backups/wazuh/`
- **Agent Logs:** `/var/ossec/logs/ossec.log`

#### Useful Commands

```bash
# Check agent status
systemctl status wazuh-agent

# View agent logs
journalctl -u wazuh-agent -f

# View installation log
cat /var/log/wazuh-install.log

# Test agent configuration
/var/ossec/bin/wazuh-control status

# Restart agent
systemctl restart wazuh-agent
```

#### Troubleshooting

If the installation fails:
1. Check the installation log: `/var/log/wazuh-install.log`
2. Verify network connectivity to Wazuh Manager
3. Ensure all system requirements are met
4. Check agent logs: `journalctl -u wazuh-agent -n 50`

#### Support

- **Wazuh Documentation:** https://documentation.wazuh.com/current/
- **Wazuh Community:** https://github.com/wazuh/wazuh/discussions

## License

This repository is licensed under the terms specified in the LICENSE file.