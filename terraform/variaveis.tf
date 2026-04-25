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

variable "spring_porta" {
  description = "Porta para aplicação Spring Boot"
  type        = number
  default     = 8080
}

variable "react_porta" {
  description = "Porta para aplicação React"
  type        = number
  default     = 80
}

variable "database_porta" {
  description = "Porta para banco de dados MySQL"
  type        = number
  default     = 3306
}

variable "s3_prefix" {
  description = "Prefixo das chaves no bucket de relatórios"
  type        = string
  default     = "vencimentos"
}

variable "db_name" {
  description = "Nome do banco de dados"
  type        = string
  default     = "toomate"
}

variable "db_user" {
  description = "Usuário do banco de dados"
  type        = string
  default     = "toomate_user"
}

variable "db_password" {
  description = "Senha do banco de dados"
  type        = string
  sensitive   = true
  default     = "toomate_password"
}

variable "schedule_expression" {
  description = "Expressão de agendamento do EventBridge (cron ou rate)"
  type        = string
  default     = "cron(0 9 * * ? *)"
}

variable "waha_porta" {
  description = "Porta para aplicação Waha"
  type        = number
  default     = 3000
}