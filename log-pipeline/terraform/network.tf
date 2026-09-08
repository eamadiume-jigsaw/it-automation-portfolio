# --- Networking -------------------------------------------------------
# A minimal VPC with two public subnets across two AZs. No NAT Gateway --
# ECS tasks get a public IP directly, which keeps this near-free for a
# short-lived lab (a NAT Gateway alone runs ~$32/month just to exist).

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.project_name}-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-igw" }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.10.${count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "${var.project_name}-public-${count.index}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- Security groups ----------------------------------------------------
resource "aws_security_group" "api" {
  name_prefix = "${var.project_name}-api-"
  description = "Allow inbound to the FastAPI ingestion service"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "API port"
    from_port   = var.api_container_port
    to_port     = var.api_container_port
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ingress_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-api-sg" }
}

resource "aws_security_group" "worker" {
  name_prefix = "${var.project_name}-worker-"
  description = "Worker needs no inbound, only egress to AWS APIs (SQS)"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-worker-sg" }
}
