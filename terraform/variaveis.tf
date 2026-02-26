variable "porta_ssh" {
  description = "Porta SSH para acesso à instância"
  type        = number
  default     = 22
}

variable "ip_qualquer" {
  description = "Permitir acesso de qualquer IP"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ipv6_qualquer" {
  description = "Permitir acesso de qualquer IP IPv6"
  type        = list(string)
  default     = ["::/0"]
}