terraform {
  required_version = ">= 0.14"
  required_providers {
    proxmox = {
      source  = "registry.example.com/telmate/proxmox"
      version = ">= 1.0.0"
    }
  }
}

provider "proxmox" {
    pm_tls_insecure = true
    pm_api_url = "https://proxmox.jimsgarage.co.uk/api2/json"
    pm_api_token_secret = <REDACTED>
    pm_api_token_id = "root@pam!terraform"
}