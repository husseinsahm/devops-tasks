output "public_lb_dns" {
  description = "The DNS of the public load balancer"
  value       = aws_elb.public.dns_name
}

output "internal_lb_dns" {
  description = "The DNS of the internal load balancer"
  value       = aws_elb.internal.dns_name
}

output "public_ec2_ips" {
  value = aws_instance.public[*].public_ip
}

output "private_ec2_ips" {
  value = aws_instance.private[*].private_ip
}
