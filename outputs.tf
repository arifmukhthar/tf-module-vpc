output "vpc_arn" {
  description = "ARN for the Bounded Context VPC"
  value       = aws_vpc.bc_vpc.arn
}

output "vpc_id" {
  description = "ID for the Bounded Context VPC"
  value       = aws_vpc.bc_vpc.id
}

output "vpc_tags" {
  description = "Tags applied to the Bounded Context VPC"
  value       = aws_vpc.bc_vpc.tags
}

output "subnets_pub_arns" {
  description = "ARNs for public subnets"
  value = {
    for number, zone in var.bc_availability_zones :
    zone => aws_subnet.bc_subnets_pub[number].arn
  }
}

output "subnets_pub_ids" {
  description = "IDs for public subnets"
  value = {
    for number, zone in var.bc_availability_zones :
    zone => aws_subnet.bc_subnets_pub[number].id
  }
}

output "subnets_pub_tags" {
  description = "Tags for public subnets"
  value = {
    for number, zone in var.bc_availability_zones :
    zone => aws_subnet.bc_subnets_pub[number].tags
  }
}

output "subnets_priv_arns" {
  description = "ARNs for private subnets"
  value = {
    for number, zone in var.bc_availability_zones :
    zone => aws_subnet.bc_subnets_priv[number].arn
  }
}

output "subnets_priv_ids" {
  description = "IDs for private subnets"
  value = {
    for number, zone in var.bc_availability_zones :
    zone => aws_subnet.bc_subnets_priv[number].id
  }
}

output "subnets_priv_tags" {
  description = "Tags for private subnets"
  value = {
    for number, zone in var.bc_availability_zones :
    zone => aws_subnet.bc_subnets_priv[number].tags
  }
}

output "internet_gateway_arn" {
  description = "ARN of the Internet Gateway"
  value       = aws_internet_gateway.bc_igw.arn
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.bc_igw.id
}

output "internet_gateway_tags" {
  description = "Tags applied to the Internet Gateway"
  value       = aws_internet_gateway.bc_igw.tags
}