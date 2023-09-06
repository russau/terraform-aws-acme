# internet gateway for internet access
resource "aws_internet_gateway" "presentation-igw" {
    vpc_id = aws_vpc.presentation-vpc.id
    tags = {
        Name = "presentation-igw"
    }
}

# create a route table that sends everything to the IGW
resource "aws_route_table" "presentation-public-crt" {
    vpc_id = aws_vpc.presentation-vpc.id
    
    route {
        cidr_block = "0.0.0.0/0" 
        gateway_id = aws_internet_gateway.presentation-igw.id
    }
    
    tags = {
        Name = "presentation-public-crt"
    }
}

# associate route table with subnet
resource "aws_route_table_association" "presentation-crta-public-subnet-1"{
    subnet_id = aws_subnet.presentation-subnet-public-1.id
    route_table_id = aws_route_table.presentation-public-crt.id
}

# security group for the webserver
resource "aws_security_group" "web-open" {
    vpc_id = aws_vpc.presentation-vpc.id
    
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    
    egress {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
    
    tags = {
        Name = "web-open"
    }
}