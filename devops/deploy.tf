provider "aws" {
  access_key = "${var.AWS_ACCESS_KEY}"
  secret_key = "${var.AWS_SECRET_KEY}"
  region     = "${var.AWS_REGION}"
}

# Create a VPC to launch our instances into
resource "aws_vpc" "production_docker" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "production_docker" {
  vpc_id = "${aws_vpc.production_docker.id}"
}

# Our default security group to access
# the instances over SSH and HTTP
resource "aws_security_group" "production_webservers" {
  name        = "production_webservers"
  description = "Used in generating webservices"
  vpc_id      = "${aws_vpc.production_docker.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 # HTTP access from the VPC
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

    ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

# SWARM ROLES
  ingress {
    from_port   = 2377
    to_port     = 2377
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 7946
    to_port     = 7946
    protocol    = "udp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 7946
    to_port     = 7946
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.production_docker.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.production_docker.id}"
}

# Create a subnet to launch our instances into
resource "aws_subnet" "production_docker" {
  vpc_id                  = "${aws_vpc.production_docker.id}"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

resource "aws_instance" "master" {
  ami           = "ami-4e686b2d"
  instance_type = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.production_webservers.id}"]
  subnet_id     = "${aws_subnet.production_docker.id}"
  key_name      = "${var.keyname}"
  connection {
        type = "ssh"
        user = "ubuntu"
        private_key = "${file(var.keyfile)}"
        timeout = "2m"
        agent = false
    }
  provisioner "file" {
    source = "docker-compose.yml"
    destination = "/home/ubuntu/docker-compose.yml"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -",
      "sudo add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\"",
      "sudo apt-get update",
      "sudo apt-get install -y docker-ce=17.06.0~ce-0~ubuntu",
      "sudo docker swarm init",
      "sudo docker swarm join-token --quiet worker > /home/ubuntu/token",
      "sudo docker stack deploy --compose-file=/home/ubuntu/docker-compose.yml app"
    ]
  }
  tags = { 
    Name = "swarm-master"
  }
}

resource "aws_instance" "slave" {
  count         = 2
  ami           = "ami-4e686b2d"
  depends_on    = ["aws_instance.master"]
  instance_type = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.production_webservers.id}"]
  subnet_id     = "${aws_subnet.production_docker.id}"
  key_name      = "${var.keyname}"
  connection {
        type = "ssh"
        user = "ubuntu"
        private_key = "${file(var.keyfile)}"
        timeout = "2m"
        agent = false
    }
  provisioner "file" {
    source = "${var.keyfile}"
    destination = "/home/ubuntu/${var.keyfile}"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -",
      "sudo add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\"",
      "sudo apt-get update",
      "sudo apt-get install -y docker-ce=17.06.0~ce-0~ubuntu",
      "sudo chmod 400 /home/ubuntu/${var.keyfile}",
      "sudo scp -o StrictHostKeyChecking=no -o NoHostAuthenticationForLocalhost=yes -o UserKnownHostsFile=/dev/null -i ${var.keyfile} ubuntu@${aws_instance.master.private_ip}:/home/ubuntu/token .",
      "sudo docker swarm join --token $(cat /home/ubuntu/token) ${aws_instance.master.private_ip}:2377"
    ]
  }
  tags = { 
    Name = "swarm-${count.index}"
  }
}

output "ip" {
    value = "To see the deployed services please go to - http://${aws_instance.master.public_ip}/go/ or http://${aws_instance.master.public_ip}/js/"
}

output "ssh" {
  value = "Please ssh to swarm master to deploy more services at - ssh -i ${var.keyfile} ubuntu@${aws_instance.master.public_ip}"
}