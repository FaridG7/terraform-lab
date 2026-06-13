# Terraform IaC — Local VM Provisioning with libvirt & cloud-init

> Provision a fully configured KVM virtual machine locally using Terraform — no cloud account required.

Inspired by the [roadmap.sh IaC on DigitalOcean](https://roadmap.sh/projects/iac-digitalocean) project, this implementation takes a **local-first approach**: instead of the DigitalOcean provider, it uses the [`dmacvicar/libvirt`](https://registry.terraform.io/providers/dmacvicar/libvirt/latest) Terraform provider to declaratively manage a KVM/QEMU virtual machine on a Linux host — at zero cloud cost.

---

## Tech Stack

| Tool | Role |
|------|------|
| **Terraform** `~> 1.15.6` | Infrastructure orchestration |
| **libvirt provider** `0.9.8` | KVM/QEMU resource management |
| **KVM / QEMU** | Type-1 hypervisor (hardware virtualization) |
| **Cloud-init** | Declarative first-boot VM configuration |
| **Ubuntu 24.04 LTS** | Guest OS (Noble Numbat cloud image) |

---

## What Gets Provisioned

A single KVM virtual machine with:

- **4 vCPUs** and **4 GiB RAM**
- **20 GiB root disk** in qcow2 format, using a copy-on-write backing store over the Ubuntu base image
- Automated first-boot configuration via **cloud-init** (hostname, users, SSH keys, packages)
- SSH key-based authentication only — password auth and root login disabled
- `ubuntu` user with passwordless sudo
- `qemu-guest-agent` installed and enabled on startup
- VirtIO network interface on the default libvirt network (DHCP, lease-based IP detection)

---

## Architecture

```
Terraform (libvirt provider)
│
├── libvirt_volume "base"          ← Ubuntu 24.04 cloud image (qcow2)
│       │
│       └── libvirt_volume "root_disk"   ← 20 GB VM disk (COW over base)
│
├── libvirt_cloudinit_disk "init"  ← Rendered from user-data.tftpl + meta-data.tftpl
│       │
│       └── libvirt_volume "cloudinit"   ← ISO attached as CD-ROM
│
└── libvirt_domain "terraform-lab"
        ├── Disk: root_disk  (virtio, vda)
        ├── Disk: cloudinit  (sata cdrom, sda)
        └── NIC:  default network (virtio, DHCP lease)
```

The COW backing store means the base image is **never modified** — each VM's root disk only stores the delta, saving significant disk space and making it trivial to spin up multiple VMs from the same image.

---

## Project Structure

```
.
├── main.tf                # All Terraform resources
├── user-data.tftpl        # Cloud-init user-data template
├── meta-data.tftpl        # Cloud-init meta-data template
├── .terraform.lock.hcl    # Provider dependency lock file
└── .gitignore             # Excludes secrets, state, and ISO files
```

---

## Prerequisites

- A Linux host with **KVM and libvirt** installed and the `libvirtd` daemon running
- **Terraform** >= 1.15.6 ([install guide](https://developer.hashicorp.com/terraform/install))
- An Ubuntu 24.04 cloud image placed at `./iso/noble-server-cloudimg-amd64.img`
- An SSH key pair on your host machine

```bash
# Install KVM and libvirt (Debian/Ubuntu)
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients virtinst
sudo usermod -aG libvirt $USER   # re-login after this

# Download the Ubuntu 24.04 cloud image
mkdir -p iso
wget -O iso/noble-server-cloudimg-amd64.img \
  https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
```

---

## Usage

**1. Clone the repository**

```bash
git clone <repo-url>
cd <repo-name>
```

**2. Create a `terraform.tfvars` file** (excluded from version control)

```hcl
vm = {
  hostname = "my-vm"
}

ssh_public_key_path = "~/.ssh/id_ed25519.pub"
```

**3. Initialize Terraform and apply**

```bash
terraform init
terraform plan
terraform apply
```

**4. Connect to the VM**

Once `apply` completes, look up the VM's DHCP-assigned IP:

```bash
virsh net-dhcp-leases default
```

Then SSH in:

```bash
ssh ubuntu@<vm-ip>
```

**5. Tear everything down**

```bash
terraform destroy
```

---

## Key Concepts Practiced

| Concept | How It Appears Here |
|---|---|
| **Infrastructure as Code** | All VM resources declared in HCL, reproducible with a single command |
| **Input variables** | `vm` map + `ssh_public_key_path` keep config out of source code |
| **Template rendering** | `templatefile()` injects variables into cloud-init payloads at plan time |
| **Cloud-init** | Handles hostname, user creation, SSH key injection, and package setup on first boot |
| **COW disk strategy** | Root disk backed by the base image — efficient, non-destructive, easy to replicate |
| **Security hardening** | No password auth, root login disabled, key-only SSH enforced via cloud-init |
| **State management** | `.gitignore` excludes `terraform.tfstate` and `.tfvars` to avoid leaking secrets |

---

## Why libvirt Instead of DigitalOcean?

The original roadmap.sh project targets DigitalOcean. Using the libvirt provider was an intentional choice to:

- Work **entirely offline** and avoid cloud costs during learning
- Understand **hypervisor-level primitives** (qcow2 volumes, cloud images, KVM domains) that cloud providers abstract away
- Get closer to how cloud providers themselves provision VMs under the hood

---

## What I Learned

- How Terraform providers work beyond the usual AWS/cloud examples
- The role of cloud-init in automating VM first-boot configuration
- How copy-on-write disk images reduce storage overhead in virtualized environments
- Terraform variable patterns for keeping secrets out of source control

---

## References

- [roadmap.sh — IaC on DigitalOcean](https://roadmap.sh/projects/iac-digitalocean) *(original project prompt)*
- [dmacvicar/terraform-provider-libvirt](https://github.com/dmacvicar/terraform-provider-libvirt)
- [cloud-init documentation](https://cloudinit.readthedocs.io/en/latest/)
- [Ubuntu cloud images](https://cloud-images.ubuntu.com/)
