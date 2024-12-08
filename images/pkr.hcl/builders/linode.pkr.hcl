variable "golang_version" {
  type = string
}

variable "variant" {
  type = string
}

variable "op_random_password" {
  type = string
}

variable "snapshot_name" {
  type = string
}

source "linode" "packer" {
  ssh_username     = "root"
  image_label      = var.snapshot_name
  instance_label   = var.snapshot_name
  image_description = "Axiom image"
  linode_token     = var.linode_key
  image            = "linode/ubuntu20.04"
  region           = var.region
  instance_type    = var.default_size
  image_create_timeout = "60m"
}

build {
  sources = [
    "source.linode.packer"
  ]

