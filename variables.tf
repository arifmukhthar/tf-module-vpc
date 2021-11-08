variable "bc_name" {
  description = "Name of the Bounded Context, used in stringbuilding"
  type        = string
  default     = "unnamed_bc"
}

variable "bc_env" {
  description = "Env. dev, staging, prod"
  type        = string

  validation {
    condition = contains(
      [
        "dev",
        "nightly",
        "staging",
        "prod"
      ],
      var.bc_env
    )
    error_message = "Bad environment name. bc_env must be one of (dev|nightly|prod|staging)."
  }
}

# No default. BC must have a CIDR block assigned before provisioning.
variable "bc_vpc_cidr" {
  description = "CIDR block assigned to the entire Bounded Context"
  type        = string

  validation {
    condition = can(
      regex(
        "^[0-9]+[.][0-9]+[.][0-9]+[.][0-9]+\\/17$",
        var.bc_vpc_cidr
      )
    )
    error_message = "Bad CIDR block. Must be a valid /17 CIDR."
  }
}

variable "subnet_prefix_extension" {
  description = "extra bits to add to the main CIDR block when creating subnets. Value of 4 creates /22s from a /17, etc."
  type        = string
  default     = "5"
}

variable "bc_region" {
  description = "Region of the Bounded Context"
  type        = string
  default     = "us-east-1"
}

variable "bc_availability_zones" {
  description = "Availability Zones used by the Bounded Context"
  type        = map

  default = {
    1 = "a",
    2 = "b",
    3 = "c"
  }
}

# Expand this with any tags that absolutely must be applied to everything
variable "bc_vpc_generic_tags" {
  description = "Generic tags to be applied to all taggable resources in the VPC. For internal use."
  type        = map

  default = {
    "terraform_managed" = "True"
  }
}

# Intentionally left blank, to be used by code that includes this module
variable "bc_vpc_defined_tags" {
  description = "Tags specific to the Bounded Context, to be applied to all taggable resources in the VPC"
  type        = map
  default     = {}
}

variable "s3_prefix_list_id" {
  description = "AWS resource id for the list of CIDR blocks assigned to S3. For use with routes directing traffic through VPC endpoint gateways."
  type        = string
  default     = "pl-63a5400a"
}

variable "dynamodb_prefix_list_id" {
  description = "AWS resource id for the list of CIDR blocks assigne do DynamoDB. For use with routes directing traffic through VPC Endpoint Gateways."
  type        = string
  default     = "pl-02cd2c6b"
}

variable "flow_log_retention_days" {
  description = "Maximum number of days to retain VPC flow logs. Possible values are: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, and 3653."
  type        = number
  default     = 14

  validation {
    condition = contains(
      [
        1,
        3,
        5,
        7,
        14,
        30,
        60,
        90,
        120,
        150,
        180,
        365,
        400,
        545,
        731,
        1827,
      3653],
      var.flow_log_retention_days
    )
    error_message = "Invalid vpc flow log retention period. Must be one of [1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653]."
  }
}

variable "component" {
  description = "Name of the component we will be deploying"
  type        = string
}
