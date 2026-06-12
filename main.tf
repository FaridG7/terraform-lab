terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.9.8"
    }
  }
  required_version = "~> 1.15.6"
}

variable "vm_hostname" {
  description = "Hostname for the virtual machine"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key"
  type        = string
}

provider "libvirt" {
  uri = "qemu:///system"
}

resource "libvirt_volume" "ubuntu_base" {
  name = "ubuntu-24.04.qcow2"
  pool = "default"

  target = {
    format = {
      type = "qcow2"
    }
  }

  create = {
    content = {
      # url = "https://cloud-images.ubuntu.com/noble/20260518/noble-server-cloudimg-amd64.img"
      url = "./iso/noble-server-cloudimg-amd64.img"
    }
  }
}

resource "libvirt_volume" "root_disk" {
  name     = "${var.vm_hostname}-root.qcow2"
  pool     = "default"
  capacity = 21474836480 # 20 GB in bytes
  target = {
    format = {
      type = "qcow2"
    }
  }
  backing_store = {
    path = libvirt_volume.ubuntu_base.path
    format = {
      type = "qcow2"
    }
  }
}

resource "libvirt_cloudinit_disk" "init" {
  name = "${var.vm_hostname}-cloudinit.iso"

  user_data = templatefile("${path.module}/cloud_init.tftpl", {
    hostname       = var.vm_hostname
    ssh_public_key = trimspace(file(var.ssh_public_key_path))
  })

  meta_data = templatefile("${path.module}/meta_data.tftpl", {
    hostname    = var.vm_hostname
    instance_id = var.vm_hostname
  })
}

resource "libvirt_volume" "cloudinit" {
  name = "${var.vm_hostname}-cloudinit"
  pool = "default"
  create = {
    content = {
      url = libvirt_cloudinit_disk.init.path
    }
  }
}

resource "libvirt_domain" "vm" {
  name        = var.vm_hostname
  memory      = 4096
  memory_unit = "MiB"
  vcpu        = 4
  type        = "kvm"

  os = {
    type = "hvm"
  }

  cpu = {
    mode = "host-passthrough"
  }

  features = {
    acpi = true
  }

  devices = {
    disks = [
      {
        target = {
          dev = "vda"
          bus = "virtio"
        }

        source = {
          volume = {
            volume = libvirt_volume.root_disk.name
            pool   = libvirt_volume.root_disk.pool
          }
        }
      },
      {
        device = "cdrom"
        target = { dev = "sda", bus = "sata" }
        source = {
          file = {
            file = libvirt_volume.cloudinit.path
          }
        }
      }
    ]

    interfaces = [
      {
        model = {
          type = "virtio"
        }
        source = {
          network = {
            network = "default"
          }
        }
      }
    ]
  }
}

output "vm_ip" {
  description = "IP address assigned to the VM"
  value       = libvirt_domain.vm.devices.interfaces[0].ip
}
