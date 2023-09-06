# find the newest nginx-demo ami
data "aws_ami" "nginx-demo" {
  most_recent      = true
  owners           = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }
}

# find the route53 zone
data "aws_route53_zone" "selected" {
  name         = local.tags.Zone
}

# instance profile to add the decrypt role
resource "aws_iam_instance_profile" "decrypt_profile" {
  name = "decrypt_profile_${var.region}"
  role = aws_iam_role.cert_decrypt_role.name
}

resource "aws_ssm_document" "install_certificate" {
  name          = "InstallTheCertForMe"
  document_type = "Command"
  content = <<DOC
{
  "schemaVersion": "2.2",
  "description": "Install cert",
  "mainSteps": [
    {
      "name" : "install",
      "action": "aws:runShellScript",
      "inputs": {
        "runCommand": [ 
          "amazon-linux-extras install -y nginx1",
          "aws s3 cp s3://${aws_s3_bucket.cert_bucket.bucket}/${aws_s3_object.web_cert_private_key.id} /etc/nginx/conf.d/privkey.pem",
          "aws s3 cp s3://${aws_s3_bucket.cert_bucket.bucket}/${aws_s3_object.web_certificate_pem.id} - | tee /etc/nginx/conf.d/fullchain.pem",
          "aws s3 cp s3://${aws_s3_bucket.cert_bucket.bucket}/${aws_s3_object.web_issuer_pem.id} - | tee -a /etc/nginx/conf.d/fullchain.pem",
          "echo \"worker_processes  1;\nevents {\n    worker_connections  1024;\n}\nhttp {\n    include       mime.types;\n    default_type  application/octet-stream;\n    sendfile        on;\n    keepalive_timeout  65;\n    server {\n        listen       80;\n        listen       443 ssl;\n        server_name  localhost;\n        ssl_certificate /etc/nginx/conf.d/fullchain.pem;\n        ssl_certificate_key /etc/nginx/conf.d/privkey.pem;\n        location / {\n            root   html;\n            index  index.html index.htm;\n        }\n\n        error_page   500 502 503 504  /50x.html;\n        location = /50x.html {\n            root   html;\n        }\n    }\n}\" | tee /etc/nginx/nginx.conf",
          "systemctl enable --now nginx",
          "systemctl restart nginx"
        ]
      }
    }
  ]
}
DOC
}

resource "aws_ssm_association" "cert-ssm-assoc" {
  association_name = "certifcate-ssm-assoc"
  name             = aws_ssm_document.install_certificate.name
  targets {
    key    = "tag:Name"
    values = ["needs-certificate"]
  }
}

# create our web server
resource "aws_instance" "secure_web1" {
    ami = data.aws_ami.nginx-demo.id
    instance_type = "t2.micro"
    iam_instance_profile = aws_iam_instance_profile.decrypt_profile.name
    subnet_id = aws_subnet.presentation-subnet-public-1.id
    vpc_security_group_ids = [ aws_security_group.web-open.id ]
    tags = {
      Name = "needs-certificate"
    }
}

# # associate an elastic IP
resource "aws_eip" "web_eip" {
  instance = aws_instance.secure_web1.id
  domain   = "vpc"
}

output "web_instance_id" {
  value = aws_instance.secure_web1.id
}

# create an A record
resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = local.tags.Domain
  type    = "A"
  ttl     = "300"
  records = [ aws_eip.web_eip.public_ip ]
}

output "web_url" {
  value = "https://${local.tags.Domain}"
}