output "alb_dns_name" {
  description = "Adresse publique de l'ALB"
  value       = module.webstack.alb_dns_name
}

output "vpc_id" {
  description = "Identifiant du VPC"
  value       = module.vpc.vpc_id
}
