terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.9.8"
    }
  }
  required_version = "~> 1.15.6"
}

variable "vm" {
  description = "Data used for the vm initialization"
  type        = map(string)
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key"
  type        = string
}

resource "libvirt_cloudinit_disk" "init" {
  name = "vm-init"
  user_data = templatefile("${path.module}/user-data.tftpl", {
    hostname       = var.vm.hostname
    ssh_public_key = trimspace(file(var.ssh_public_key_path))
  })

  meta_data = templatefile("${path.module}/meta-data.tftpl", {
    hostname    = var.vm.hostname
    instance_id = var.vm.hostname
  })
}

resource "libvirt_volume" "cloudinit" {
  name = "vm-cloudinit"
  pool = "default"
  target = {
    format = {
      type = "raw"
    }
  }

  create = {
    content = {
      url = libvirt_cloudinit_disk.init.path
    }
  }
}
