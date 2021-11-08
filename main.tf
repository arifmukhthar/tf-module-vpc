# Basic config for a bounded-context VPC

# This file is long. If you would like to improve it, you can break off
# individual sections and turn them into submodules. You will need to define
# outputs for each resource attribute that is used elsewhere, while also
# making sure to capture all needed variables. It will be fractally fun.
#
# Any such changes should take care not to break the downstream use of
# this module.

terraform {
  required_version = ">= 0.13.0"
}

locals {
  suffix = "${var.bc_env}_${var.bc_name}"
  all_tags = merge(
    {
      "bounded_context" = var.bc_name
      "env"             = var.bc_env
    },
    var.bc_vpc_generic_tags,
    var.bc_vpc_defined_tags
  )

  vpc_tags = merge(
    {
      "Name" = "vpc_${local.suffix}"
    },
    local.all_tags
  )

  default_tags = merge(
    {
      "Name" = "default_${local.suffix}"
    },
    local.all_tags
  )

  private_name = "private_${local.suffix}"
  private_tags = merge(
    {
      "Name" = local.private_name
    },
    local.all_tags
  )

  internet_gateway_tags = merge(
    {
      "Name" = "ig_${local.suffix}"
    },
    local.all_tags
  )

  flow_log_name = "fl_${var.component}_${local.suffix}"
  flow_logs_tags = merge(
    {
      "Name" = local.flow_log_name
    },
    local.all_tags
  )

  public_route_tags = merge(
    {
      "Name" = "public_rt_${local.suffix}"
    },
    local.all_tags
  )

  s3_endpoint_tags = merge(
    {
      "Name" = "s3_endpoint_${local.suffix}"
    },
    local.all_tags
  )

  dynamodb_endpoint_tags = merge(
    {
      "Name" = "dynamodb_endpoint_${local.suffix}"
    },
    local.all_tags
  )
}

# Begin basic VPC setup
# Only basic resources that exist at the VPC level should be here.
resource "aws_vpc" "bc_vpc" {
  instance_tenancy     = "default"
  cidr_block           = var.bc_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = false
  tags                 = local.vpc_tags
}

# Terraform cannot delete the default security group that comes with a VPC,
# but it can take control and snip out the default rules.
resource "aws_default_security_group" "default_sg" {
  vpc_id = aws_vpc.bc_vpc.id
  tags   = local.default_tags
}

# Terraform cannot delete the default route table that comes with a VPC,
# but it can take control and snip out default routes.
resource "aws_default_route_table" "default_rt" {
  default_route_table_id = aws_vpc.bc_vpc.default_route_table_id
  tags                   = local.default_tags
}

# This is the egress point for all traffic not sent through Endpoints or
# Peering connections. Traffic sent to NAT Gateways will still eventually
# come through here, just with the EIP as the origin address on the packets.
resource "aws_internet_gateway" "bc_igw" {
  vpc_id = aws_vpc.bc_vpc.id
  tags   = local.internet_gateway_tags
}
## End basic VPC setup

## Begin VPC flow Logs setup
# Only configs directly related to flow logs for the VPC should be here.
resource "aws_flow_log" "bc_vpc_flow_log" {
  vpc_id          = aws_vpc.bc_vpc.id
  traffic_type    = "ALL"
  log_destination = aws_cloudwatch_log_group.bc_vpc_flow_logs.arn
  iam_role_arn    = aws_iam_role.flow_logs_assume_allow.arn
  tags            = local.flow_logs_tags
}

resource "aws_iam_role" "flow_logs_assume_allow" {
  # Do not set 'name' to a dynamically generated value. It is not a tag, and
  # changes require destruction and recreation.
  name               = local.flow_log_name
  assume_role_policy = data.aws_iam_policy_document.flow_logs_assume_allow.json
  tags               = local.flow_logs_tags
}

resource "aws_iam_role_policy" "flow_logs_role_policy" {
  name   = local.flow_log_name
  role   = aws_iam_role.flow_logs_assume_allow.id
  policy = data.aws_iam_policy_document.flow_logs_role_policy.json
}

resource "aws_cloudwatch_log_group" "bc_vpc_flow_logs" {
  # Do not set 'name' to a dynamically generated value. It is not a tag, and
  # changes require destruction and recreation.
  name              = local.flow_log_name
  retention_in_days = var.flow_log_retention_days
  tags              = local.flow_logs_tags
}
## End VPC flow logs setup

## Begin subnet setup
# Only VPC Subnets and the things allocated for their direct use should be here.
# Begin subnet definitions
resource "aws_subnet" "bc_subnets_pub" {
  for_each                = var.bc_availability_zones
  vpc_id                  = aws_vpc.bc_vpc.id
  availability_zone       = "${var.bc_region}${each.value}"
  map_public_ip_on_launch = true
  cidr_block = cidrsubnet(
    var.bc_vpc_cidr,
    var.subnet_prefix_extension,
    each.key
  )
  tags = merge(
    {
      "Name" = "pub_${each.value}_${local.suffix}"
    },
    local.all_tags
  )
}

resource "aws_subnet" "bc_subnets_priv" {
  for_each          = var.bc_availability_zones
  vpc_id            = aws_vpc.bc_vpc.id
  availability_zone = "${var.bc_region}${each.value}"
  # There will be twice as many subnets as zones, with these
  # private subnets being the second half
  cidr_block = cidrsubnet(
    var.bc_vpc_cidr,
    var.subnet_prefix_extension,
    each.key + length(var.bc_availability_zones)
  )
  tags = merge(
    {
      "Name" = "priv_${each.value}_${local.suffix}"
    },
    local.all_tags
  )
}
# End subnet definitions

# Begin gateway definitions
resource "aws_eip" "bc_elastic_ips" {
  for_each = var.bc_availability_zones
  vpc      = true
  tags = merge(
    {
      "Name" = "eip_${each.value}_${local.suffix}"
    },
    local.all_tags
  )
}

resource "aws_nat_gateway" "bc_nat_gateways" {
  for_each      = var.bc_availability_zones
  allocation_id = aws_eip.bc_elastic_ips[each.key].id
  subnet_id     = aws_subnet.bc_subnets_pub[each.key].id
  tags = merge(
    {
      "Name" = "nat_${each.value}_${local.suffix}"
    },
    local.all_tags
  )
}
# End gateway definitions

# Begin public route table definitions
resource "aws_route_table" "bc_public_route_table" {
  # DO NOT ADD INLINE RULES
  # Inline rules preclude the use of "route" resources, and routes will be different
  # per Bounded Context based on VPC peering connections
  vpc_id = aws_vpc.bc_vpc.id
  # Individual routes and their associations cannot be tagged, so make sure
  # what ends up here is complete
  tags = local.public_route_tags
}

# Public subnets don't need separate route tables
resource "aws_route_table_association" "bc_public_route_table_subnet_associations" {
  for_each       = var.bc_availability_zones
  route_table_id = aws_route_table.bc_public_route_table.id
  subnet_id      = aws_subnet.bc_subnets_pub[each.key].id
}

resource "aws_route" "bc_public_route_table_egress_route" {
  route_table_id         = aws_route_table.bc_public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.bc_igw.id

  timeouts {
    create = "5m"
  }
}

# This route, where the VPC CIDR is mapped to local, is the default route and is
# created implicitly. It cannot be set, but is being included here to assure that
# it was not forgotten. Same goes for the private subnets.
#
#resource "aws_route" "bc_vpc_public_route_table_internal_route" {
#  route_table_id         = aws_route_table.bc_vpc_public_route_table.id
#  destination_cidr_block = var.bc_vpc_cidr
#  gateway_id             = "local"
#}
#
# End public route table definitions

# Begin private route table definitions
#
# Each private subnet will have its own NAT Gateway, so each needs a separate
# route table
resource "aws_route_table" "bc_vpc_private_route_tables" {
  # DO NOT ADD INLINE RULES
  # Inline rules preclude the use of "route" resources, and routes will be different
  # per Bounded Context based on VPC peering connections
  for_each = var.bc_availability_zones
  vpc_id   = aws_vpc.bc_vpc.id
  tags = merge(
    {
      "Name" = "private_${each.value}_rt_${local.suffix}"
    },
    local.all_tags
  )
}

resource "aws_route_table_association" "bc_private_route_tables_subnet_associations" {
  for_each       = var.bc_availability_zones
  route_table_id = aws_route_table.bc_vpc_private_route_tables[each.key].id
  subnet_id      = aws_subnet.bc_subnets_priv[each.key].id
}

resource "aws_route" "bc_private_route_tables_egress_routes" {
  for_each               = var.bc_availability_zones
  route_table_id         = aws_route_table.bc_vpc_private_route_tables[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.bc_nat_gateways[each.key].id
}
# End private route table definitions
## End subnet setup

## Begin VPC Endpoint definitions
# Only VPC Endpoints (Gateway or Interface) should be here
#
# Traffic from resources in private subnets will use these to communicate with
# AWS services, without having to travel through NAT Gateways and incur costs.
# VPC endpoints can also have access policies assigned, which may become useful.
#
# Begin VPC Endpoint Gateway definitions
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.bc_vpc.id
  service_name      = "com.amazonaws.${var.bc_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [
    for route_table in aws_route_table.bc_vpc_private_route_tables :
    route_table.id
  ]
  tags = local.s3_endpoint_tags
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.bc_vpc.id
  service_name      = "com.amazonaws.${var.bc_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [
    for route_table in aws_route_table.bc_vpc_private_route_tables :
    route_table.id
  ]
  tags = local.dynamodb_endpoint_tags
}
# End VPC Endpoint Gateway definitions
## End VPC Endpoint setup

## Begin base Security Group definitions
# Only the bare minimum security group configs should be here. More complex
# ones should be in modules for their related resources.
resource "aws_security_group" "base_private_sg" {
  # DO NOT ADD INLINE RULES.
  # Do not set 'name' to a dynamically generated value. It is not a tag, and
  # changes require the destruction and recreation of the group. This will
  # leave certain AWS resources (like VPC Endpoint Interfaces) completely
  # broken and unfixable in-place.
  name        = local.private_name
  description = "base security group for all private resources"
  vpc_id      = aws_vpc.bc_vpc.id
  tags        = local.private_tags
}
## End base Security Group definitions
