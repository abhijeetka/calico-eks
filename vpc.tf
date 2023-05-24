
resource "aws_vpc" "eks_vpc" {
  cidr_block           = "192.168.240.0/20"
  enable_dns_hostnames = true

  tags = merge(local.tags, {
    "kubernetes.io/cluster/${local.name}" = "shared"
  })
}

resource "aws_subnet" "eks_public_subnet_1" {
  cidr_block              = "192.168.242.0/24"
  vpc_id                  = aws_vpc.eks_vpc.id
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = merge(local.tags, {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/elb"              = "1"
  })
}
resource "aws_subnet" "eks_public_subnet_2" {
  cidr_block              = "192.168.243.0/24"
  vpc_id                  = aws_vpc.eks_vpc.id
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = merge(local.tags, {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/elb"              = "1"
  })
}

resource "aws_subnet" "eks_private_subnet_1" {
  cidr_block              = "192.168.244.0/24"
  vpc_id                  = aws_vpc.eks_vpc.id
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = merge(local.tags, {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/internal-elb"     = "1"
  })
}

resource "aws_subnet" "eks_private_subnet_2" {
  cidr_block              = "192.168.245.0/24"
  vpc_id                  = aws_vpc.eks_vpc.id
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false

  tags = merge(local.tags, {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/internal-elb"     = "1"
  })
}

# Create NAT Gateway
# Create EIP
resource "aws_eip" "eks_nat_eip" {
  vpc = true

  tags = local.tags
}

resource "aws_nat_gateway" "eks_nat_gateway" {
  allocation_id = aws_eip.eks_nat_eip.id
  subnet_id     = aws_subnet.eks_public_subnet_1.id

  tags = local.tags
}

#########

# Create Internet Gateway
resource "aws_internet_gateway" "eks_ig" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = local.tags
}

## Creation of Route tables

resource "aws_route_table" "eks_public_subnet_rt" {
  vpc_id = aws_vpc.eks_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks_ig.id
  }

  tags = local.tags
}

resource "aws_route_table" "eks_private_subnet_rt" {
  vpc_id = aws_vpc.eks_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.eks_nat_gateway.id
  }

  tags = local.tags
}

resource "aws_route_table_association" "eks_rt_public_subnet_associate_1" {
  route_table_id = aws_route_table.eks_public_subnet_rt.id
  subnet_id      = aws_subnet.eks_public_subnet_1.id

}

resource "aws_route_table_association" "eks_rt_public_subnet_associate_2" {
  route_table_id = aws_route_table.eks_public_subnet_rt.id
  subnet_id      = aws_subnet.eks_public_subnet_2.id

}

resource "aws_route_table_association" "eks_rt_private-subnet_associate_1" {
  route_table_id = aws_route_table.eks_private_subnet_rt.id
  subnet_id      = aws_subnet.eks_private_subnet_1.id

}

resource "aws_route_table_association" "eks_rt_private-subnet_associate_2" {
  route_table_id = aws_route_table.eks_private_subnet_rt.id
  subnet_id      = aws_subnet.eks_private_subnet_2.id

}











































