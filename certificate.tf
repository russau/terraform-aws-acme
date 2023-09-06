# create an RSA key to authenticate to Let's Encrypt
resource "tls_private_key" "private_key" {
  algorithm = "RSA"
}

# register with Let's Encrypt
resource "acme_registration" "reg" {
  account_key_pem = tls_private_key.private_key.private_key_pem
  email_address   = "russ@tinisles.com"
}

# request a cert from Let's Encrypt, a TXT record on route 53 is used for domain verification
resource "acme_certificate" "certificate" {
  account_key_pem           = acme_registration.reg.account_key_pem
  common_name               = local.tags.Domain

  dns_challenge {
    provider = "route53"
  }
}

# create a KMS key
resource "aws_kms_key" "cert_key" {
  description = "cert key"
  is_enabled  = true
}

# create an ec2 role
data "aws_iam_policy_document" "instance-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# https://stackoverflow.com/questions/45002292/terraform-correct-way-to-attach-aws-managed-policies-to-a-role
# A data resource is used to describe data or resources that are not actively managed by Terraform, but are referenced by Terraform
data "aws_iam_policy" "AmazonSSMManagedInstanceCore" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# role can decrypt the private key
resource "aws_iam_role" "cert_decrypt_role" {
  name               = "cert_decrypt_role_${var.region}"
  assume_role_policy = data.aws_iam_policy_document.instance-assume-role-policy.json
  managed_policy_arns = [data.aws_iam_policy.AmazonSSMManagedInstanceCore.arn]
}

resource "aws_iam_role_policy" "cert_decrypt_policy" {
  name = "cert_decrypt_policy_${var.region}"
  role = aws_iam_role.cert_decrypt_role.id

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "kms:Decrypt",
        "Effect": "Allow",
        "Resource": "${aws_kms_key.cert_key.arn}"
      },
      {
        "Action": [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        "Effect": "Allow",
        "Resource": ["${aws_s3_bucket.cert_bucket.arn}","${aws_s3_bucket.cert_bucket.arn}/*" ]
      }
    ]
  }
  EOF
}

resource "aws_s3_bucket" "cert_bucket" {
  bucket = "rrs-cert-bucket-${var.region}"
}

resource "aws_s3_object" "web_cert_private_key" {
  key        = "${local.tags.Domain}_cert_private_key"
  bucket     = aws_s3_bucket.cert_bucket.id
  content     = acme_certificate.certificate.private_key_pem
  kms_key_id = aws_kms_key.cert_key.arn
}

resource "aws_s3_object" "web_certificate_pem" {
  key        = "${local.tags.Domain}_certificate_pem"
  bucket     = aws_s3_bucket.cert_bucket.id
  content     = acme_certificate.certificate.certificate_pem
  kms_key_id = aws_kms_key.cert_key.arn
}

resource "aws_s3_object" "web_issuer_pem" {
  key        = "${local.tags.Domain}_issuer_pem"
  bucket     = aws_s3_bucket.cert_bucket.id
  content     = acme_certificate.certificate.issuer_pem
  kms_key_id = aws_kms_key.cert_key.arn
}
