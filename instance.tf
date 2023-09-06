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
  document_format = "YAML"
  content = <<EOT
---
schemaVersion: "2.2"
description: "install cert"
parameters:
mainSteps:
- action: "aws:runShellScript"
  name: "certInstaller"
  inputs:
    runCommand:
    - |-
      #!/bin/bash
      amazon-linux-extras install -y nginx1
      aws s3 cp s3://${aws_s3_bucket.cert_bucket.bucket}/${aws_s3_object.web_cert_private_key.id} /etc/nginx/conf.d/privkey.pem
      aws s3 cp s3://${aws_s3_bucket.cert_bucket.bucket}/${aws_s3_object.web_certificate_pem.id} - | tee /etc/nginx/conf.d/fullchain.pem
      aws s3 cp s3://${aws_s3_bucket.cert_bucket.bucket}/${aws_s3_object.web_issuer_pem.id} - | tee -a /etc/nginx/conf.d/fullchain.pem
      cat << EOF | tee /etc/nginx/nginx.conf
      worker_processes  1;
      events {
          worker_connections  1024;
      }
      http {
          include       mime.types;
          default_type  application/octet-stream;
          sendfile        on;
          keepalive_timeout  65;
          server {
              listen       80;
              listen       443 ssl;
              server_name  localhost;
              ssl_certificate /etc/nginx/conf.d/fullchain.pem;
              ssl_certificate_key /etc/nginx/conf.d/privkey.pem;
              location / {
                  root   html;
                  index  index.html index.htm;
              }

              error_page   500 502 503 504  /50x.html;
              location = /50x.html {
                  root   html;
              }
          }
      }
      EOF

      systemctl enable --now nginx
      systemctl restart nginx
EOT
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
resource "aws_instance" "secure_web" {
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
  instance = aws_instance.secure_web.id
  domain   = "vpc"
}

output "web_instance_id" {
  value = aws_instance.secure_web.id
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