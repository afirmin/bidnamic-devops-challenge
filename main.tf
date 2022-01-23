########################################################################
# Configure the AWS Provider
provider "aws" {
  region = "eu-west-2"
}

########################################################################

module "iam" {
  source  = "terraform-aws-modules/iam/aws"
  version = "3.6.0"
}

########################################################################
# Configure the VPC

resource "aws_vpc" "bidnamitest-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "bidnamitest-vpc"
  }
}

########################################################################
# Configure the internet gateway

resource "aws_internet_gateway" "bidnamitest-igw" {
  vpc_id = aws_vpc.bidnamitest-vpc.id

  tags = {
    Name = "bidnamitest-igw"
  }
}

########################################################################
# Configure the custom route table

resource "aws_route_table" "bidnamitest-route-table" {
  vpc_id = aws_vpc.bidnamitest-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.bidnamitest-igw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.bidnamitest-igw.id
  }

  tags = {
    Name = "bidnamitest-route-table"
  }
}

########################################################################
# Configure the subnet

resource "aws_subnet" "bidnamitest-subnet1" {
  vpc_id     = aws_vpc.bidnamitest-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-west-2b"
  tags = {
    Name = "bidnamitest-subnet1"
  }
}

########################################################################
# Associate the route table with the subnet

resource "aws_route_table_association" "bidnamitest-rta1" {
  subnet_id      = aws_subnet.bidnamitest-subnet1.id
  route_table_id = aws_route_table.bidnamitest-route-table.id
}

########################################################################
# Configure security group

resource "aws_security_group" "bidnamitest-sg" {
  name        = "bidnamitest-allow-web-traffic"
  description = "Only allow ssh traffic"
  vpc_id      = aws_vpc.bidnamitest-vpc.id

  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ssh"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Bidnamitest-allow-web"
  }
}

########################################################################
# Configure network interface

resource "aws_network_interface" "bidnamitest-nic1" {
  subnet_id       = aws_subnet.bidnamitest-subnet1.id
  private_ips     = ["10.0.1.5"]
  security_groups = [aws_security_group.bidnamitest-sg.id]
}

# resource "aws_network_interface_attachment" "bidnamitest-nic1-nia" {
#  instance_id          = aws_instance.bidnamitest-svr1.id
#  network_interface_id = bidnamitest-nic1.id
#  device_index         = 0
#}

########################################################################
# Configure elastic ip

resource "aws_eip" "bidnamitest-eip1" {
  vpc                       = true
  network_interface         = aws_network_interface.bidnamitest-nic1.id
  associate_with_private_ip = "10.0.1.5"
  depends_on                = [aws_internet_gateway.bidnamitest-igw]
}

########################################################################
# Configure instance

resource "aws_instance" "bidnamitest-svr1" {
  ami           = "ami-00f6a0c18edb19300"
  instance_type = "t2.micro"
  availability_zone = "eu-west-2b"
  key_name      = "bidnami"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.bidnamitest-nic1.id
  }
  user_data = <<-EOUD
#!/usr/bin/env bash

#
# get pip and python and get them set up
#
wget https://bootstrap.pypa.io/get-pip.py
sudo apt-get install -y python3-distutils python3-apt python3-testresources make
sudo ln -s /usr/bin/python3.8 /usr/bin/python
python get-pip.py
echo "export PATH=/home/vagrant/.local/bin:$PATH" >> .profile
source ~/.profile
pip install git+git://github.com/psf/black
pip install pylint

#
# download the repo
#
wget https://github.com/afirmin/bidnamic-devops-challenge/archive/refs/heads/mastee
r.zip
unzip master.zip

cd bidnamic-devops-challenge-master

source make-the-makefile.sh



  EOUD



  tags = {
      Name =  "Bidnamitest-Websvr1"
  }
}

output "server_private_ip" {
    value = aws_instance.bidnamitest-svr1.private_ip
}
output "server_public_ip" {
    value = aws_instance.bidnamitest-svr1.public_ip
}

#
###########################################################################
#  IAM Schizzle

resource "aws_iam_user" "bdmnuser" {
  name = "bidnami-test-user"
  path = "/system/"

  tags = {
    tag-key = "bdmn-user-tag"
  }
}

resource "aws_iam_access_key" "bdmn-ak" {
  user = aws_iam_user.bdmnuser.name
}

resource "aws_iam_user_policy" "bdmn-up" {
  name = "test"
  user = aws_iam_user.bdmnuser.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:Describe*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}
