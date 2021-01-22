provider "aws" {
  region = "eu-west-1"
}

resource "aws_cloudwatch_log_group" "datachef" {
  name = "datachef"

  tags = local.tags
}


locals {
  # Common tags to be assigned to all resources
    username = "pooria"
tags = {
    Owner   = "pghaedi"
}
}

resource "aws_iam_role" "sftp-logging" {
  name = "sftp-logging-role"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
        "Effect": "Allow",
        "Principal": {
            "Service": "transfer.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
        }
    ]
}
EOF
  tags = local.tags
}

resource "aws_iam_role_policy" "sftp-logging" {
  name = "sftp-logging-policy"
  role = aws_iam_role.sftp-logging.id

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:DescribeLogStreams",
                "logs:CreateLogGroup",
                "logs:PutLogEvents"
            ],
            "Resource": "${aws_cloudwatch_log_group.datachef.arn}/*"
        }
    ]
}
POLICY

}


resource "aws_s3_bucket" "datachef" {
  bucket = "datachefassignment"
 
}

resource "aws_transfer_ssh_key" "datachef" {
  server_id = aws_transfer_server.datachef.id
  user_name = aws_transfer_user.datachef.user_name
  body      = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCqkU+hdSPbod6Qs0uD3+fNzE8kUdQ8x0dkZVRhcGJ5xhDC2b7TsJUrPcpQjwjMap/F9y717UmXxUFloHQ/jd/cEh31Vcfx2qhsz+4UaPwS5S6PXwGMITAB2WVz1Sp8nnc2DhbyQ/rWnW+AAflvS7/OgUR0nAZ5r2YfuiQXiTPuH+lZTrA3j16mliIM4IBW7qHibg4B+MCYjpSVyCQICcrqxK+cyRMqLOiGzj+kJblplwJnDI7eZIsadJTNeLtPS2vWeAuOHn9ZCUbycdB4jO3VHp0ImuMLsyNkwAn9ZaZ6ih/qrcwsSe+02Svu95J3WtoQEk0XZaWZTCgx/yqAHkuj root@obfs"
}

resource "aws_transfer_server" "datachef" {
  identity_provider_type = "SERVICE_MANAGED"
  endpoint_type 	 = "PUBLIC"
  logging_role		 = aws_iam_role.sftp-logging.arn
  tags = local.tags
}

resource "aws_transfer_user" "datachef" {
  server_id = aws_transfer_server.datachef.id
  user_name = local.username
  role      = aws_iam_role.datachef.arn
  home_directory = "/${aws_s3_bucket.datachef.bucket}/home/${local.username}/"

  tags = {
    owner = "pghaedi"
  }
}

resource "aws_iam_role" "datachef" {
  name = "datachef-assignment-transfer-user-iam-role"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
        "Effect": "Allow",
        "Principal": {
            "Service": "transfer.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "datachef" {
  name = "tf-test-transfer-user-iam-policy"
  role = aws_iam_role.datachef.id

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListAllMyBuckets",
                "s3:GetBucketLocation"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "s3:ListBucket",
            "Resource": "arn:aws:s3:::${aws_s3_bucket.datachef.bucket}",
            "Condition": {
                "StringLike": {
                    "s3:prefix": [
                        "",
                        "home/",
                        "home/${local.username}/*"
                    ]
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::${aws_s3_bucket.datachef.bucket}/home/${local.username}",
                "arn:aws:s3:::${aws_s3_bucket.datachef.bucket}/home/${local.username}*/*"
            ]
        }
    ]
}
POLICY
}

