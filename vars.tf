variable "region" {
  default = "ap-southeast-2"
}

locals {
  tags = {
    Domain ="${var.region}-peach.beta-seattle.net"
    Zone = "beta-seattle.net."
  }
}
