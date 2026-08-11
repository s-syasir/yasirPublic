resource "proxmox_vm_qemu" "cloudinit-k3s-master" {
    # Node name has to be the same name as within the cluster
    # this might not include the FQDN
    target_node = "proxmox-dell"
    desc = "Cloudinit Ubuntu"
    count = 3
    onboot = true

    # The template name to clone this vm from
    clone = "23.04-non-KVM"

    # Activate QEMU agent for this VM
    agent = 0

    os_type = "cloud-init"
    cores = 2
    sockets = 2
    numa = true
    vcpus = 0
    cpu = "host"
    memory = 4096
    name = "k3s-master-0${count.index + 1}"

    cloudinit_cdrom_storage = "nvme"
    scsihw   = "virtio-scsi-single" 
    bootdisk = "scsi0"

    disks {
        scsi {
            scsi0 {
                disk {
                  storage = "nvme"
                  size = 12
                }
            }
        }
    }

    # Setup the ip address using cloud-init.
    # Keep in mind to use the CIDR notation for the ip.
    ipconfig0 = "ip=<LAN_IP>${count.index + 1}/24,gw=<LAN_IP>"
    ciuser = "ubuntu"
    nameserver = "<LAN_IP>"
    sshkeys = <<EOF
ssh-rsa <SSH_PUBKEY>
    EOF
}

resource "proxmox_vm_qemu" "cloudinit-k3s-worker" {
    # Node name has to be the same name as within the cluster
    # this might not include the FQDN
    target_node = "proxmox-dell"
    desc = "Cloudinit Ubuntu"
    count = 2
    onboot = true

    # The template name to clone this vm from
    clone = "23.04-non-KVM"

    # Activate QEMU agent for this VM
    agent = 0

    os_type = "cloud-init"
    cores = 2
    sockets = 2
    numa = true
    vcpus = 0
    cpu = "host"
    memory = 4096
    name = "k3s-worker-0${count.index + 1}"

    cloudinit_cdrom_storage = "nvme"
    scsihw   = "virtio-scsi-single" 
    bootdisk = "scsi0"

    disks {
        scsi {
            scsi0 {
                disk {
                  storage = "nvme"
                  size = 12
                }
            }
        }
    }

    # Setup the ip address using cloud-init.
    # Keep in mind to use the CIDR notation for the ip.
    ipconfig0 = "ip=<LAN_IP>${count.index + 1}/24,gw=<LAN_IP>"
    ciuser = "ubuntu"
    sshkeys = <<EOF
ssh-rsa <SSH_PUBKEY>
    EOF
}