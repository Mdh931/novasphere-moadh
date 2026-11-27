variable "owner" {
  description = "Responsable des ressources"
  type        = string
}

variable "environment" {
  description = "Environnement déployé"
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment doit valoir dev ou prod."
  }
}

variable "vpc_cidr" {
  description = "Plage d'adresses du VPC"
  type        = string
}

variable "instance_type" {
  description = "Type d'instance EC2"
  type        = string
  default     = "t3.micro"
}

variable "app_message" {
  description = "Titre affiché sur la page d'accueil"
  type        = string
  default     = "NovaSphere v2"
}

variable "app_secret" {
  description = "Secret applicatif, fourni par TF_VAR_app_secret, jamais écrit dans un fichier"
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "app_secret_version" {
  description = "À incrémenter pour réécrire le secret dans Parameter Store"
  type        = number
  default     = 2
}
