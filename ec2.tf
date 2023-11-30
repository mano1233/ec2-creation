data "aws_vpc" "this" {
  tags = {
    Name = "vpc-snd-euw1"
  }
}

variable "subnet_filter_tags" {
  type        = map(string)
  description = "(Optional) Use subnet tags to pick which subnets to be used for EKS cluster networking and Node Groups networking."
  default = {
    "appsflyer.com/access" = "private"
  }
}

# Subnets to be used
data "aws_subnets" "this" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this.id]
  }
  tags = var.subnet_filter_tags
}

variable "subnet_ids" {
  type        = list(string)
  default     = []
  description = "(Optional) List of subnets ids to be used for EKS cluster and Node Groups networking."
  validation {
    condition = alltrue([
      for value in var.subnet_ids :
      can(regex("subnet-.*", value))
    ])
    error_message = "Subnet ID provided is not valid, must start with \"subnet-{{ID}}\"."
  }
}

resource "aws_security_group" "tal_basestation" {
  name        = "webserver"
  vpc_id      = data.aws_vpc.this.id
  description = "Allows access to Web Port"
  #allow http
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["192.168.0.0/24"]
  }
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["18.66.0.0/24"]
  }
  #all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    stack = "test"
  }
}


data "template_file" "startup" {
  template = file("startup.sh")
}

resource "aws_instance" "ec2" {
  ami                    = "ami-07355fe79b493752d"
  instance_type          = "t2.micro"
  subnet_id              = data.aws_subnets.this.ids[0]
  vpc_security_group_ids = [aws_security_group.tal_basestation.id]
  iam_instance_profile   = aws_iam_instance_profile.dev-resources-iam-profile.name
  //key_name               = aws_key_pair.ITKey.key_name
  root_block_device {
    delete_on_termination = true
    volume_type           = "gp2"
    volume_size           = 20
  }
  user_data = data.template_file.startup.rendered
}


provider "aws" {
  region     = "eu-west-1"
}

resource "aws_iam_instance_profile" "dev-resources-iam-profile" {
  name = "ec2_profile"
  role = aws_iam_role.dev-resources-iam-role.name
}
resource "aws_iam_role" "dev-resources-iam-role" {
  name        = "dev-ssm-role"
  description = "The role for the developer resources EC2"
  assume_role_policy = <<EOF
{
"Version": "2012-10-17",
"Statement": {
"Effect": "Allow",
"Principal": {"Service": "ec2.amazonaws.com"},
"Action": "sts:AssumeRole"
}
}
EOF
  tags = {
    stack = "test"
  }
}
resource "aws_iam_role_policy_attachment" "dev-resources-ssm-policy" {
  role       = aws_iam_role.dev-resources-iam-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}