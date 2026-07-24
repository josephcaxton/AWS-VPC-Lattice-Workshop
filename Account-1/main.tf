
# Configuring the AWS provider and general variables...

terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.3"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type        = string
  default     = "eu-west-2"
  description = "The target AWS Region for workshop deployment."
}

variable "environment" {
  type        = string
  default     = "lattice-workshop"
  description = "Resource naming prefix."
}

# Retrieve AZs dynamically for multi-AZ subnet distribution
data "aws_availability_zones" "available" {
  state = "available"
}

# Retrieve the latest Amazon Linux 2023 AMI with SSM Agent pre-installed
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}
# Create VPC A (Client/Consumer Environment)

resource "aws_vpc" "vpc_a" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.environment}-vpc-a-client"
  }
}

# Subnet 1 in VPC A (AZ 1)
resource "aws_subnet" "vpc_a_private_1" {
  vpc_id            = aws_vpc.vpc_a.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.environment}-vpc-a-priv-1"
  }
}
# Subnet 2 in VPC A (AZ 2)
resource "aws_subnet" "vpc_a_private_2" {
  vpc_id            = aws_vpc.vpc_a.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "${var.environment}-vpc-a-priv-2"
  }
}

# Private Route Table for VPC A
resource "aws_route_table" "vpc_a_route_table" {
  vpc_id = aws_vpc.vpc_a.id

  tags = {
    Name = "${var.environment}-vpc-a-rt"
  }
}
# Subnet Route Table Associations for VPC A
resource "aws_route_table_association" "vpc_a_assoc_1" {
  subnet_id      = aws_subnet.vpc_a_private_1.id
  route_table_id = aws_route_table.vpc_a_route_table.id
}

resource "aws_route_table_association" "vpc_a_assoc_2" {
  subnet_id      = aws_subnet.vpc_a_private_2.id
  route_table_id = aws_route_table.vpc_a_route_table.id
}

# Initializing VPC B with overlapping IP space...
#Create VPC B (Backend/Provider Environment) with EXACT same CIDR block (overlapping IP pattern)
#resource "aws_vpc" "vpc_b" {
#  cidr_block           = "10.0.0.0/16"
#  enable_dns_hostnames = true
#  enable_dns_support   = true
#
#  tags = {
#    Name = "${var.environment}-vpc-b-backend"
#  }
#}
## Subnet 1 in VPC B (AZ 1)
#resource "aws_subnet" "vpc_b_private_1" {
#  vpc_id            = aws_vpc.vpc_b.id
#  cidr_block        = "10.0.1.0/24"
#  availability_zone = data.aws_availability_zones.available.names[0]
#
#  tags = {
#    Name = "${var.environment}-vpc-b-priv-1"
#  }
#}
#
##Subnet 2 in VPC B (AZ 2)
#resource "aws_subnet" "vpc_b_private_2" {
#  vpc_id            = aws_vpc.vpc_b.id
#  cidr_block        = "10.0.2.0/24"
#  availability_zone = data.aws_availability_zones.available.names[1]
#
#  tags = {
#    Name = "${var.environment}-vpc-b-priv-2"
#  }
#}
#
## Private Route Table for VPC B
#resource "aws_route_table" "vpc_b_route_table" {
#  vpc_id = aws_vpc.vpc_b.id
#
#  tags = {
#    Name = "${var.environment}-vpc-b-rt"
#  }
#}
#
##Subnet Route Table Associations for VPC B
#resource "aws_route_table_association" "vpc_b_assoc_1" {
#  subnet_id      = aws_subnet.vpc_b_private_1.id
#  route_table_id = aws_route_table.vpc_b_route_table.id
#}
#
#resource "aws_route_table_association" "vpc_b_assoc_2" {
#  subnet_id      = aws_subnet.vpc_b_private_2.id
#  route_table_id = aws_route_table.vpc_b_route_table.id
#}
# Creating security groups for isolated communication...
# Security Group for EC2 Client in VPC A
resource "aws_security_group" "client_sg" {
  name        = "${var.environment}-client-sg"
  description = "Allows outbound traffic for the Client EC2"
  vpc_id      = aws_vpc.vpc_a.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
  # Allow all standard outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.environment}-client-sg"
  }
}

# Security Group for Backend Web Server in VPC B
#resource "aws_security_group" "backend_sg" {
#  name        = "${var.environment}-backend-sg"
#  description = "Allows incoming traffic from AWS VPC Lattice link-local space"
#  vpc_id      = aws_vpc.vpc_b.id
#
#  #Inbound HTTP (80) from local VPC and VPC Lattice prefix ranges (169.254.171.0/24)
#
#  ingress {
#    from_port   = 80
#    to_port     = 80
#    protocol    = "tcp"
#    cidr_blocks = ["10.0.0.0/16", "169.254.171.0/24"]
#  }
#
#  egress {
#    from_port   = 0
#    to_port     = 0
#    protocol    = "-1"
#    cidr_blocks = ["0.0.0.0/0"]
#  }
#
#  tags = {
#    Name = "${var.environment}-backend-sg"
#  }
#}
#Security Group for VPC Endpoints in VPC A (SSM interface endpoints)

resource "aws_security_group" "vpc_endpoints_sg" {
  name        = "${var.environment}-endpoints-sg"
  description = "Enables communication to Systems Manager within private VPC A"
  vpc_id      = aws_vpc.vpc_a.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-endpoints-sg"
  }
}
# Provisioning IAM roles for EC2 and Lambda execution...
#IAM Execution Role for Client EC2 Instance (VPC A)

resource "aws_iam_role" "client_role" {
  name = "${var.environment}-client-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

#Attach standard Systems Manager core policy so attendees can use Session Manager
resource "aws_iam_role_policy_attachment" "ssm_core_attachment" {
  role       = aws_iam_role.client_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
# Add IAM Inline Policy to Client Role for executing and invoking VPC Lattice Services in Lab 3
resource "aws_iam_role_policy" "lattice_invoke_policy" {
  name = "${var.environment}-lattice-invoke"
  role = aws_iam_role.client_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["vpc-lattice-svc:Invoke"]
        Resource = "*"
      }
    ]
  })
}

#Create IAM Instance Profile to attach role to Client EC2 instance
resource "aws_iam_instance_profile" "client_profile" {
  name = "${var.environment}-client-instance-profile"
  role = aws_iam_role.client_role.name
}

# IAM Role for AWS Lambda V2 (Canary Backend)
resource "aws_iam_role" "lambda_role" {
  name = "${var.environment}-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Attach basic lambda execution role to write CloudWatch logs
resource "aws_iam_role_policy_attachment" "lambda_logs_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Creating Systems Manager endpoints for isolated access...

# Since VPC A is entirely private with no NAT Gateways, we create VPC Endpoints
# for AWS Systems Manager (SSM) so users can interact with the client EC2 safely.
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.vpc_a.id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
  subnet_ids          = [aws_subnet.vpc_a_private_1.id, aws_subnet.vpc_a_private_2.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.environment}-endpoint-ssm"
  }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.vpc_a.id
  service_name        = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
  subnet_ids          = [aws_subnet.vpc_a_private_1.id, aws_subnet.vpc_a_private_2.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.environment}-endpoint-ssmmessages"
  }
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = aws_vpc.vpc_a.id
  service_name        = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
  subnet_ids          = [aws_subnet.vpc_a_private_1.id, aws_subnet.vpc_a_private_2.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.environment}-endpoint-ec2messages"
  }
}

# Deploying Client EC2 instance in VPC A...

# Create the Client EC2 Instance where attendees will execute curl testing commands
resource "aws_instance" "client_instance" {
  ami                    = data.aws_ssm_parameter.al2023_ami.value
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.vpc_a_private_1.id
  vpc_security_group_ids = [aws_security_group.client_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.client_profile.name

  tags = {
    Name = "${var.environment}-client-instance"
  }
}

# Create the Backend App V1 Server in VPC B. It hosts a simple python-based

# HTTP server listening on Port 80, serving "Hello from App V1"
#resource "aws_instance" "backend_instance" {
#  ami                    = data.aws_ssm_parameter.al2023_ami.value
#  instance_type          = "t3.micro"
#  subnet_id              = aws_subnet.vpc_b_private_1.id
#  vpc_security_group_ids = [aws_security_group.backend_sg.id]
#
#  # User Data scripts configure a self-contained local python microservice web host
#  user_data = <<-EOF
##!/bin/bash
#mkdir -p /app
#echo "Hello from App V1" > /app/index.html
#cd /app
#python3 -m http.server 80 &
#EOF
#  tags = {
#    Name = "${var.environment}-backend-v1-instance"
#  }
#}
# Preparing Serverless Lambda target for Canary V2...

#Bundle the Lambda script inline for robust deployments without dependencies
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda.zip"
  source {
    content  = <<EOF
def lambda_handler(event, context):
return {
'statusCode': 200,
'headers': {
'Content-Type': 'application/json'
},
'body': '{"message": "Hello from App V2 (Canary)"}'
}
EOF
    filename = "index.py"
  }
}

# Deploy Lambda Function representing App V2 (Canary target for Lab 4)
resource "aws_lambda_function" "canary_lambda" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.environment}-canary-v2"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.11"
  timeout          = 15

  tags = {
    Name = "${var.environment}-canary-v2-lambda"
  }
}

# Outputs for Feature Verification
output "vpc_a_id" {
  value       = aws_vpc.vpc_a.id
  description = "The ID of the Client/Consumer VPC A"
}

#output "vpc_b_id" {
#  value       = aws_vpc.vpc_b.id
#  description = "The ID of the Backend/Provider VPC B"
#}

output "client_instance_id" {
  value       = aws_instance.client_instance.id
  description = "The Instance ID of the Client, used to establish SSM console sessions"
}

#output "backend_instance_id" {
#  value       = aws_instance.backend_instance.id
#  description = "The Instance ID of the App V1 Backend Server"
#}

output "lambda_arn" {
  value       = aws_lambda_function.canary_lambda.arn
  description = "The ARN of the App V2 Lambda, used for Target Group association"
}

