variable "cloud_id" {
  description = "Cloud"
}
variable "folder_id" {
  description = "Folder"
}
variable "zone" {
  description = "Zone"
  default     = "ru-central1-a"
}
variable "region_id" {
  description = "region"
  default     = "ru-central1"
}
variable "public_key_path" {
  description = "Path to the public key used for ssh access"
}
variable "image_id" {
  description = "Disk image"
}
variable "subnet_id" {
  description = "Subnet"
}
variable "service_account_key_file" {
  description = "key.json"
}
variable "private_key_path" {
  description = "path to private key"
}
variable "k8s_account_id" {
  description = "k8s_account_id"
}
variable "network_id" {
  description = "network id"
}
variable "dns_account" {
  description = "dns account login"
}
variable "dns_password" {
  description = "dns account password"
}
variable "project_domain" {
  description = "projec domain name"
}
variable "public_key_path_ed" {
  description = "public_key_path_ed"
}
variable "automation_token" {
  description = "token"
}
variable "docker_user" {
  description = "docker_user"
}
variable "docker_pass" {
  description = "docker_pass"
}
variable "project_group" {
  description = "projec group name"
}
