# vpc network
resource "aws_vpc" "presentation-vpc" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support = "true"
    enable_dns_hostnames = "true"

    tags = {
        Name = "presentation-vpc"
    }
}

# get a list of AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# public subnet
resource "aws_subnet" "presentation-subnet-public-1" {
    vpc_id = aws_vpc.presentation-vpc.id
    cidr_block = "10.0.1.0/24"
    map_public_ip_on_launch = "true"
    availability_zone = data.aws_availability_zones.available.names[var.region == "ap-northeast-1" ? 1 : 0]
    tags = {
        Name = "presentation-subnet-public-1"
    }
}
