provider "aws" {
  /*
  $ export AWS_ACCESS_KEY_ID=YOUR_AWS_ACCESS_KEY_ID
  $ export AWS_SECRET_ACCESS_KEY=YOUR_AWS_SECRET_ACCESS_KEY
  $ export AWS_DEFAULT_REGION=us-east-1
  */
  region      = "${var.region}"
  access_key  = "${var.access_key}"
  secret_key  = "${var.secret_key}"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["${var.ami}"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_key_pair" "kismatic" {
  key_name   = "${var.cluster_name}"
  public_key = "${file("${var.public_ssh_key_path}")}"
}

resource "aws_vpc" "kismatic" {
  cidr_block            = "10.0.0.0/16"
  enable_dns_support    = true
  enable_dns_hostnames  = true
  tags {
    Name                  = "${var.cluster_name}"
    kubernetes.io/cluster = "${var.cluster_name}"
    kismatic/ClusterName  = "${var.cluster_name}"
    kismatic/ClusterOwner = "${var.cluster_owner}"
  }
}

resource "aws_internet_gateway" "kismatic_gateway" {
  vpc_id = "${aws_vpc.kismatic.id}"
  tags {
    Name                  = "${var.cluster_name}"
    kubernetes.io/cluster = "${var.cluster_name}"
    kismatic/ClusterName  = "${var.cluster_name}"
    kismatic/ClusterOwner = "${var.cluster_owner}"
  }
}

resource "aws_default_route_table" "kismatic_router" {
  default_route_table_id = "${aws_vpc.kismatic.default_route_table_id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.kismatic_gateway.id}"
  }

  tags {
    Name                  = "${var.cluster_name}"
    kubernetes.io/cluster = "${var.cluster_name}"
    kismatic/ClusterName  = "${var.cluster_name}"
    kismatic/ClusterOwner = "${var.cluster_owner}"
  }
}

resource "aws_subnet" "kismatic_public" {
  vpc_id      = "${aws_vpc.kismatic.id}"
  cidr_block  = "10.0.1.0/24"
  map_public_ip_on_launch = "True"
  tags {
    Name                  = "${var.cluster_name}-public"
    kubernetes.io/cluster = "${var.cluster_name}"
    kismatic/ClusterName  = "${var.cluster_name}"
    kismatic/ClusterOwner = "${var.cluster_owner}"
    kismatic/Subnet       = "public"
  }
}

resource "aws_subnet" "kismatic_private" {
  vpc_id      = "${aws_vpc.kismatic.id}"
  cidr_block  = "10.0.2.0/24"
  map_public_ip_on_launch = "False"
  tags {
    Name                  = "${var.cluster_name}-private"
    kubernetes.io/cluster = "${var.cluster_name}"
    kismatic/ClusterName  = "${var.cluster_name}"
    kismatic/ClusterOwner = "${var.cluster_owner}"
    kismatic/Subnet       = "private"
  }
}

resource "aws_subnet" "kismatic_master" {
  count       = "${var.master_count > 1 ? 1 : 0}"
  vpc_id      = "${aws_vpc.kismatic.id}"
  cidr_block  = "10.0.3.0/24"
  map_public_ip_on_launch = "False"
  tags {
    Name                  = "${var.cluster_name}-master"
    kubernetes.io/cluster = "${var.cluster_name}"
    kismatic/ClusterName  = "${var.cluster_name}"
    kismatic/ClusterOwner = "${var.cluster_owner}"
    kismatic/Subnet       = "master"
  }
}

resource "aws_subnet" "kismatic_ingress" {
  count       = "${var.ingress_count > 1 ? 1 : 0}"
  vpc_id      = "${aws_vpc.kismatic.id}"
  cidr_block  = "10.0.4.0/24"
  map_public_ip_on_launch = "False"
  tags {
    Name                  = "${var.cluster_name}-ingress"
    kubernetes.io/cluster = "${var.cluster_name}"
    kismatic/ClusterName  = "${var.cluster_name}"
    kismatic/ClusterOwner = "${var.cluster_owner}"
    kismatic/Subnet       = "ingress"
  }
}

resource "aws_security_group" "kismatic_public_sg" {
  name        = "${var.cluster_name}-public"
  description = "Allow inbound SSH and ICMP pings."
  vpc_id      = "${aws_vpc.kismatic.id}"

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    self        = "True"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name                  = "${var.cluster_name}-public"
    kubernetes.io/cluster = "${var.cluster_name}"
    kismatic/ClusterName  = "${var.cluster_name}"
    kismatic/ClusterOwner = "${var.cluster_owner}"
    kismatic/SecurityGroup  = "public"
  }
}

resource "aws_security_group" "kismatic_private_sg" {
  name        = "${var.cluster_name}/private"
  description = "Allow all communication between nodes."
  vpc_id      = "${aws_vpc.kismatic.id}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = "True"
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags {
    Name                  = "${var.cluster_name}-private"
    kubernetes.io/cluster = "${var.cluster_name}"
    kismatic/ClusterName  = "${var.cluster_name}"
    kismatic/ClusterOwner = "${var.cluster_owner}"
    kismatic/SecurityGroup  = "private"
  }


resource "aws_security_group" "kismatic_apiserver_lb_sg" {
  name        = "${var.cluster_name}-apiserver-lb"
  description = "Allow inbound on 6443 for kube-apiserver load balancer."
  vpc_id      = "${aws_vpc.kismatic.id}"

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name                  = "${var.cluster_name}-apiserver-lb"
    kubernetes.io/cluster = "${var.cluster_name}"
    kismatic/ClusterName  = "${var.cluster_name}"
    kismatic/ClusterOwner = "${var.cluster_owner}"
    kismatic/SecurityGroup  = "apiserver_lb"
  }
}

resource "aws_security_group" "kismatic_ingress_lb_sg" {
  name        = "${var.cluster_name}-ingress-lb"
  description = "Allow inbound on 80 and 443 for ingress load balancer."
  vpc_id      = "${aws_vpc.kismatic.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name                  = "${var.cluster_name}-ingress-lb"
    kubernetes.io/cluster = "${var.cluster_name}"
    kismatic/ClusterName  = "${var.cluster_name}"
    kismatic/ClusterOwner = "${var.cluster_owner}"
    kismatic/SecurityGroup  = "apiserver_lb"
  }
}

resource "aws_s3_bucket" "lb_logs" {
  count  = "${var.master_count > 1 || var.ingress_count > 1 ? 1 : 0}"
  bucket = "${var.cluster_name}/lb_logs"
  acl    = "private"

  logging {
    target_bucket = "${aws_s3_bucket.lb_logs.id}"
    target_prefix = "log/"
  }
  tags {
    Name                  = "${var.cluster_name}-lb-logs"
    kubernetes.io/cluster = "${var.cluster_name}"
    kismatic/ClusterName  = "${var.cluster_name}"
    kismatic/ClusterOwner = "${var.cluster_owner}"
    kismatic/Bucket       = "lb"
  }
}

resource "aws_lb" "kismatic_apiserver_lb" {
  count           = "${var.master_count} > 1 ? 1 : 0"
  name            = "${var.cluster_name}/apiserver-lb"
  internal        = false
  security_groups = ["${aws_security_group.kismatic_apiserver_lb_sg.id}"]
  subnets         = ["${aws_subnet.kismatic_public.id}"]

  access_logs {
    bucket = "${aws_s3_bucket.lb_logs.bucket}"
    prefix = "${var.cluster_name}"
  }

  subnet_mapping {
    subnet_id = "${aws_subnet.kismatic_master.id}"
  }

  tags {
    Name                  = "${var.cluster_name}-apiserver-lb"
    kubernetes.io/cluster = "${var.cluster_name}"
    kismatic/ClusterName  = "${var.cluster_name}"
    kismatic/ClusterOwner = "${var.cluster_owner}"
    kismatic/LoadBalancer  = "apiserver"
  }
}

resource "aws_lb" "kismatic_ingress_lb" {
  name            = "${var.cluster_name}/ingress-lb"
  internal        = false
  security_groups = ["${aws_security_group.kismatic_lb_sg.id}"]
  subnets         = ["${aws_subnet.kismatic_public.id}"]

  access_logs {
    bucket = "${aws_s3_bucket.lb_logs.bucket}"
    prefix = "${var.cluster_name}"
  }

  tags {
    Name                  = "${var.cluster_name}-ingress-lb"
    kubernetes.io/cluster = "${var.cluster_name}"
    kismatic/ClusterName  = "${var.cluster_name}"
    kismatic/ClusterOwner = "${var.cluster_owner}"
    kismatic/LoadBalancer  = "ingress"
  }
}

resource "aws_instance" "bastion" {
  vpc_security_group_ids = ["${aws_security_group.kismatic_public_sg.id}"]
  subnet_id       = "${aws_subnet.kismatic_public.id}"
  key_name        = "${var.cluster_name}"
  count           = "${var.master_count}"
  ami             = "${data.aws_ami.ubuntu.id}"
  instance_type   = "${var.instance_size}"
  tags {
    Name                  = "${var.cluster_name}-bastion"
    kubernetes.io/cluster = "${var.cluster_name}"
    kismatic/ClusterName  = "${var.cluster_name}"
    kismatic/ClusterOwner = "${var.cluster_owner}"
    kismatic/NodeRoles  = "bastion"
  }

    provisioner "remote-exec" {
      inline = ["echo ready"]

      connection {
        type = "ssh"
        user = "${var.ssh_user}"
        private_key = "${file("${var.private_ssh_key_path}")}"
        timeout = "2m"
      }
    }
}

resource "aws_instance" "master" {
  vpc_security_group_ids = ["${aws_security_group.kismatic_public_sg.id}"]
  subnet_id       = "${var.master_count > 1 ? aws_subnet.kismatic_private.id : aws_subnet.kismatic_public.id}"
  key_name        = "${var.cluster_name}"
  count           = "${var.master_count}"
  ami             = "${data.aws_ami.ubuntu.id}"
  instance_type   = "${var.instance_size}"
  tags {
    Name                  = "${var.cluster_name}-master"
    kubernetes.io/cluster = "${var.cluster_name}"
    kismatic/ClusterName  = "${var.cluster_name}"
    kismatic/ClusterOwner = "${var.cluster_owner}"
    kismatic/NodeRoles  = "master"
  }

  provisioner "remote-exec" {
    inline = ["echo ready"]

    connection {
      type = "ssh"
      user = "${var.ssh_user}"
      private_key = "${file("${var.private_ssh_key_path}")}"
      timeout = "2m"
    }
  }
}

resource "aws_instance" "etcd" {
  vpc_security_group_ids = ["${aws_security_group.kismatic_public_sg.id}"]
  subnet_id       = "${aws_subnet.kismatic_private.id}"
  key_name        = "${var.cluster_name}"
  count           = "${var.etcd_count}"
  ami             = "${data.aws_ami.ubuntu.id}"
  instance_type   = "${var.instance_size}"
  tags {
    Name                  = "${var.cluster_name}-etcd"
    kubernetes.io/cluster = "${var.cluster_name}"
    kismatic/ClusterName  = "${var.cluster_name}"
    kismatic/ClusterOwner = "${var.cluster_owner}"
    kismatic/NodeRoles  = "etcd"
  }

  provisioner "remote-exec" {
    inline = ["echo ready"]

    connection {
      type = "ssh"
      user = "${var.ssh_user}"
      private_key = "${file("${var.private_ssh_key_path}")}"
      timeout = "2m"
    }
  }
}

resource "aws_instance" "worker" {
  vpc_security_group_ids = ["${aws_security_group.kismatic_public_sg.id}"]
  subnet_id       = "${aws_subnet.kismatic_private.id}"
  key_name        = "${var.cluster_name}"
  count           = "${var.worker_count}"
  ami             = "${data.aws_ami.ubuntu.id}"
  instance_type   = "${var.instance_size}"
  tags {
    Name                  = "${var.cluster_name}-worker"
    kubernetes.io/cluster = "${var.cluster_name}"
    kismatic/ClusterName  = "${var.cluster_name}"
    kismatic/ClusterOwner = "${var.cluster_owner}"
    kismatic/NodeRoles  = "worker"
  }

  provisioner "remote-exec" {
    inline = ["echo ready"]

    connection {
      type = "ssh"
      user = "${var.ssh_user}"
      private_key = "${file("${var.private_ssh_key_path}")}"
      timeout = "2m"
    }
  }
}

resource "aws_instance" "ingress" {
  vpc_security_group_ids = ["${aws_security_group.kismatic_public_sg.id}"]
  subnet_id       = "${var.ingress_count > 1 ? aws_subnet.kismatic_private.id : aws_subnet.kismatic_public.id}"
  key_name        = "${var.cluster_name}"
  count           = "${var.ingress_count}"
  ami             = "${data.aws_ami.ubuntu.id}"
  instance_type   = "${var.instance_size}"
  tags {
    Name                  = "${var.cluster_name}-ingress"
    kubernetes.io/cluster = "${var.cluster_name}"
    kismatic/ClusterName  = "${var.cluster_name}"
    kismatic/ClusterOwner = "${var.cluster_owner}"
    kismatic/NodeRoles  = "ingress"
  }

  provisioner "remote-exec" {
    inline = ["echo ready"]

    connection {
      type = "ssh"
      user = "${var.ssh_user}"
      private_key = "${file("${var.private_ssh_key_path}")}"
      timeout = "2m"
    }
  }
}

resource "aws_instance" "storage" {
  vpc_security_group_ids = ["${aws_security_group.kismatic_public_sg.id}"]
  subnet_id       = "${aws_subnet.kismatic_private.id}"
  key_name        = "${var.cluster_name}"
  count           = "${var.storage_count}"
  ami             = "${data.aws_ami.ubuntu.id}"
  instance_type   = "${var.instance_size}"
  tags {
    Name                  = "${var.cluster_name}-storage"
    kubernetes.io/cluster = "${var.cluster_name}"
    kismatic/ClusterName  = "${var.cluster_name}"
    kismatic/ClusterOwner = "${var.cluster_owner}"
    kismatic/NodeRoles  = "storage"
  }

  provisioner "remote-exec" {
    inline = ["echo ready"]

    connection {
      type = "ssh"
      user = "${var.ssh_user}"
      private_key = "${file("${var.private_ssh_key_path}")}"
      timeout = "2m"
    }
  }
}