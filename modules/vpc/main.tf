#provider "aws" {
#  region = "ap-southeast-1"
#}
resource "aws_vpc" "my_vpc" {
  cidr_block           = var.vpc_cidr # "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name                                                      = "${var.project}-vpc-${var.environment}"
    "kubernetes.io/cluster/${var.project}-${var.environment}" = "shared"
    Project                                                   = var.project
    environment                                               = var.environment
    Tier                                                      = var.tier
    CreatedBy                                                 = "terraform"
  }
}
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = element(var.public_subnets_cidr, count.index)
  availability_zone       = element(var.availability_zones_public, count.index)
  count                   = length(var.public_subnets_cidr)
  map_public_ip_on_launch = true
  depends_on              = [aws_vpc.my_vpc]

  tags = {

    "kubernetes.io/cluster/${var.project}-${var.environment}" = "shared"
    "kubernetes.io/role/elb"                                  = 1
    Name                                                      = "${var.environment}-public-${count.index + 1}"
    state                                                     = "public"
    Project                                                   = var.project
    environment                                               = var.environment
    Tier                                                      = var.tier
    CreatedBy                                                 = "terraform"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = element(var.private_subnets_cidr, count.index)
  availability_zone = element(var.availability_zones_private, count.index)
  count             = length(var.private_subnets_cidr)
  depends_on        = [aws_vpc.my_vpc]

  tags = {

    "kubernetes.io/cluster/${var.project}-${var.environment}" = "shared"
    "kubernetes.io/role/internal-elb"                         = 1
    "Name"                                                    = "${var.environment}-private-${count.index + 1}"
    "state"                                                   = "private"
    Project                                                   = var.project
    environment                                               = var.environment
    Tier                                                      = var.tier
    CreatedBy                                                 = "terraform"
  }
}

resource "aws_subnet" "secure" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = element(var.secure_subnets_cidr, count.index)
  availability_zone = element(var.availability_zones_secure, count.index)
  count             = length(var.secure_subnets_cidr)
  depends_on        = [aws_vpc.my_vpc]

  tags = {

    "Name"      = "${var.environment}-secure-${count.index + 1}"
    "state"     = "secure"
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}
resource "aws_internet_gateway" "my_gw" {
  vpc_id     = aws_vpc.my_vpc.id
  depends_on = [aws_vpc.my_vpc]

  tags = {
    Name        = "${var.project}-internet-gateway-${var.environment}"
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}

resource "aws_eip" "nat" {
  count            = 2
  domain           = "vpc"
  public_ipv4_pool = "amazon"
  tags = {
    Name        = "${var.project}-eip-nat-${count.index + 1}-${var.environment}"
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}

resource "aws_nat_gateway" "my_nat_gw" {
  count         = 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  depends_on    = [aws_internet_gateway.my_gw]

  tags = {
    Name        = "${var.project}-nat-gateway-${var.environment}-${count.index + 1}"
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}

resource "aws_route_table" "internet_route" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_gw.id
  }
  depends_on = [aws_vpc.my_vpc]
  tags = {
    Name        = "${var.project}-public-route-table-${var.environment}"
    state       = "public"
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}

resource "aws_route_table" "nat_route" {
  vpc_id = aws_vpc.my_vpc.id
  count  = length(var.private_subnets_cidr)
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.my_nat_gw[count.index % 2].id
  }
  depends_on = [aws_vpc.my_vpc]
  tags = {
    Name        = "${var.project}-nat-route-table-${count.index + 1}-${var.environment}"
    state       = "public"
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets_cidr)
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.internet_route.id

  depends_on = [aws_route_table.internet_route,
    aws_subnet.public
  ]
}


resource "aws_route_table_association" "private" {
  count          = length(var.public_subnets_cidr)
  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = element(aws_route_table.nat_route.*.id, count.index)
  depends_on = [aws_route_table.nat_route,
    aws_subnet.private
  ]
}



#security group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "${var.project}-alb-sg-${var.environment}"
  description = "managed by Terraform"
  vpc_id      = aws_vpc.my_vpc.id
  ingress {
    from_port   = 80
    to_port     = 80 # Disallow the http traffic in ALB SG 
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow http traffic access from all"
  }
  ingress {
    from_port   = 3000
    to_port     = 3000 # Disallow the http traffic in ALB SG 
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow http traffic access from all"
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow https traffic access from all"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name        = "${var.project}-alb-sg-${var.environment}"
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}
resource "aws_security_group" "cms_sg" {
  name        = "${var.project}-cms-sg-${var.environment}"
  description = "managed by Terraform"
  vpc_id      = aws_vpc.my_vpc.id
  ingress {
    from_port   = 80
    to_port     = 80 # Disallow the http traffic in ALB SG 
    protocol    = "tcp"
    cidr_blocks = ["134.209.110.31/32", "188.166.235.62/32", "103.70.228.0/22", "35.219.200.53/32", "82.26.90.83/32"]
    description = "Allow http traffic access from all"
  }
  ingress {
    from_port   = 3000
    to_port     = 3000 # Disallow the http traffic in ALB SG 
    protocol    = "tcp"
    cidr_blocks = ["134.209.110.31/32", "188.166.235.62/32", "103.70.228.0/22", "35.219.200.53/32", "82.26.90.83/32"]
    description = "Allow http traffic access from all"
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["134.209.110.31/32", "188.166.235.62/32", "103.70.228.0/22", "35.219.200.53/32", "82.26.90.83/32"]
    description = "Allow https traffic access from all"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name        = "${var.project}-cms-sg-${var.environment}"
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}
resource "aws_security_group" "vpce_sg" {
  name        = "${var.project}-vpce-sg-${var.environment}"
  description = "managed by Terraform"
  vpc_id      = aws_vpc.my_vpc.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name        = "${var.project}-vpce-sg-${var.environment}"
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}
resource "aws_security_group" "eks_sg" {
  name        = "${var.project}-eks-sg-${var.environment}"
  description = "managed by Terraform"
  vpc_id      = aws_vpc.my_vpc.id
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.alb_sg.id]
    description     = "Allow all traffic access from alb_sg"
  }
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "Allow all traffic access from own sg"
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Allow all traffic access from vpc cidr"
  }
  # ingress {
  #   cidr_blocks      = []
  #   description      = "Allow all traffic access from Lambda"
  #   from_port        = 0
  #   ipv6_cidr_blocks = []
  #   prefix_list_ids  = []
  #   protocol         = "-1"
  #   security_groups  = ["sg-025adcb9feba26588",]
  #   self             = false
  #   to_port          = 0
  # }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name        = "${var.project}-eks-sg-${var.environment}"
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}
resource "aws_security_group" "secure_sg" {
  name        = "${var.project}-secure-sg-${var.environment}"
  description = "managed by Terraform"
  vpc_id      = aws_vpc.my_vpc.id
  // Ingress rules
  # ingress {
  #   description      = "Dynatrace"
  #   from_port        = 0
  #   protocol         = "-1"  # SG Hardcode not expected 
  #   security_groups  = [
  #       "sg-00c6c46bb6e743f6f",
  #     ]
  #   to_port          = 0
  # }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS"
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    self        = true // Allow traffic from own security group
    description = "https access from the same security group"
  }
  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Elastic cache access"
  }
  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    self        = true // Allow traffic from own security group
    description = "Allow redis access from the same security group"
  }
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Allow postgres connection"
  }
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    self        = true // Allow traffic from own security group
    description = "Allow postgres access from the same security group"
  }
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.eks_sg.id, aws_security_group.appstream_sg.id, aws_security_group.kibana_alb_sg.id]
    description     = "Allow all for security groups eks_sg,appstream_sg"
  }
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true // Allow traffic from own security group
    description = "Allow all access from the same security group"
  }


  # Egress rules
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name        = "${var.project}-secure-sg-${var.environment}"
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}
resource "aws_security_group" "appstream_sg" {
  name        = "${var.project}-appstream-sg-${var.environment}"
  description = "managed by Terraform"
  vpc_id      = aws_vpc.my_vpc.id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow All traffic access to access appstream"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name        = "${var.project}-appstream-sg-${var.environment}"
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}
resource "aws_security_group" "kibana_alb_sg" {
  name        = "${var.project}-kibana-alb-sg-${var.environment}"
  description = "managed by Terraform"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["134.209.110.31/32", "188.166.235.62/32", "103.70.228.0/22"]
    description = "Allow All traffic access to access appstream"
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.102.176.0/22"]
    description = "Robi VPN"
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.102.218.0/25"]
    description = "Robi IT VPN"
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["103.119.100.253/32"]
    description = "Shakir"
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["103.166.187.125/32"]
    description = "Selim Bhai AIO"
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["103.213.242.115/32"]
    description = "Sayfee"
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["202.52.40.245/32"]
    description = "Sayfee Bhai IP 21june"
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["202.134.11.242/32"]
    description = "TEMP IP"
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["202.134.12.117/32"]
    description = "tfdemo-Production-Cluster"
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["202.134.12.41/32", "202.134.12.42/32", "202.134.12.44/32"]
    description = ""
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["202.134.12.43/32"]
    description = "tfdemo-Staging-Cluster"
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["212.129.72.138/32"]
    description = "AKRAM IP 2"
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["212.129.83.79/32"]
    description = "AKRAM IP 1"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}
resource "aws_security_group" "efs_sg" {
  name        = "${var.project}-efs-sg-${var.environment}"
  description = "managed by Terraform"
  vpc_id      = aws_vpc.my_vpc.id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "Allow All traffic access from the same security group"
  }
  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Allow All traffic access from the same security group"
  }
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.eks_sg.id]
    description     = "Allow All traffic access from eks_sg security group"
  }
  # Egress rules
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name        = "${var.project}-efs-sg-${var.environment}"
    Project     = var.project
    environment = var.environment
    Tier        = var.tier
    CreatedBy   = "terraform"
  }
}