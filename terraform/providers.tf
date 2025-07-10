terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Default provider for global resources (Route53)
provider "aws" {
  region = "us-east-1"
  
  endpoints {
    sts             = "http://localhost:4566"
    iam             = "http://localhost:4566"
    ec2             = "http://localhost:4566"
    ecs             = "http://localhost:4566"
    elasticloadbalancingv2 = "http://localhost:4566"
    route53         = "http://localhost:4566"
    logs            = "http://localhost:4566"
    ecr             = "http://localhost:4566"
    s3              = "http://localhost:4566"
  }
  
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  
  s3_use_path_style = true
  
  access_key = "test"
  secret_key = "test"
}

# Provider for us-east-1
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
  
  endpoints {
    sts             = "http://localhost:4566"
    iam             = "http://localhost:4566"
    ec2             = "http://localhost:4566"
    ecs             = "http://localhost:4566"
    elasticloadbalancingv2 = "http://localhost:4566"
    route53         = "http://localhost:4566"
    logs            = "http://localhost:4566"
    ecr             = "http://localhost:4566"
    s3              = "http://localhost:4566"
  }
  
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  
  s3_use_path_style = true
  
  access_key = "test"
  secret_key = "test"
}

# Provider for us-east-2
provider "aws" {
  alias  = "us-east-2"
  region = "us-east-2"
  
  endpoints {
    sts             = "http://localhost:4566"
    iam             = "http://localhost:4566"
    ec2             = "http://localhost:4566"
    ecs             = "http://localhost:4566"
    elasticloadbalancingv2 = "http://localhost:4566"
    route53         = "http://localhost:4566"
    logs            = "http://localhost:4566"
    ecr             = "http://localhost:4566"
    s3              = "http://localhost:4566"
  }
  
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  
  s3_use_path_style = true
  
  access_key = "test"
  secret_key = "test"
}