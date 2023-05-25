variable "region" {
  default = "us-east-1"
}

variable "cluster_name" {
  default = "calico-eks"
}

variable "environment" {
  default = "devops"
}

variable "team" {
  default = "devops"
}

variable "PATH_TO_PUBLIC_KEY" {
  default = "./ssh-key.pub"
}


variable "key_pair" {
  description = "Name of keypair to be configure"
  default     = ""
}

variable "cluster_version" {
  default = "1.23"
}
