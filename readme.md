# VPC

This module will create a single VPC and all associated network components.
Each VPC will have:
* 1 Internet Gateway
* 1 VPC Endpoint Gateway for S3
* 1 VPC Endpoint Gateway for DynamoDB
* 1 CloudWatch log group for retaining VPC flow logs
* 1 Route table for all public subnets
* 1 The 'default' Route Table captured with external routes disabled
* 1 The 'default' Security Group captured with all rules disabled

Each availability zone (default a and b) will have:
* 1 Public subnet
* 1 Private subnet
* 1 NAT Gateway
* 1 Elastic IP attached to the NAT Gateway
* 1 Route Table for the private subnet with base rules for each NAT and Endpoint Gateway

# Required Inputs

## bc_vpc_cidr
No default. This is the base CIDR block to be used. Terraform will fail a run if this it not provided. No new bounded context should be provisioned until Architecture has selected a CIDR block for use.

## bc_name
Default is `"unnamed_bc"`. You can use this module without setting it, but if your new Bounded Context doesn't even have a name you shouldn't be building the infrastructure yet.

## bc_env
No default. Used with `bc_name` to set the prefix for all naming of resources. Experimental variable validation has been activated to ensure this is one of `dev`, `prod`, or `staging`.

## component
No default. Used with creating unique names to allow multiple vpc in same account with different cidr blocks.

# Optional Inputs

## bc_region
Default is `us-east-1`.

## bc_availability_zones
Default is:
    {
      1 = "a",
      2 = "b"
    }

To change this, pass in a complete map of all desired availability zones. The keys must always be integers starting from `1`, as they are used by `cidrsubnet()` to track the total number of subnets while calculating them off the primary CIDR block. Simple lists are not supported by `for_each` and `toset()` discards ordering and index information.

## subnet_prefix_extension
Default is `"4"`. Used to determine the size of the subnets to be created, by adding bits to the base CIDR prefix. The default setting means a `/20` VPC will have `/24` subnets created, while a `/16` VPC will have `/20` subnets created. Adjust this value if you want bigger or smaller subnets.

## bc_vpc_defined_tags
This is a map for applying tags to AWS resources. Key and Value are used for tag name and content respectively. This should at a minimum be overridden to update the bounded context name.

## flow_log_retention_days
Default is `14`. How long the CloudWatch log group for VPC flow logging should retain events. Variable validation is in place to ensure bad values are caught before an apply is attempted. See `variables.tf` for valid values.

# Default things
Terraform cannot be used to destroy - it is meant for configuring things that exist, and for later destroying them when you are done using them. Because of this design decision, the default security group and route table provisioned with a new VPC cannot be removed. There are, however, special terraform resource objects for managing these: `aws_default_security_group` and `aws_default_route_table`. These have been used here to explicitly strip all ingress and egress, while leaving them in place as defaults for use by anyone who is inattentively manually creating things in the console.

The default VPC will need to be handled externally, in whatever bootstrap script is used for initializing new AWS accounts.
