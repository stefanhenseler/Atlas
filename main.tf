# Rancher AWS Infrastructure
# Main "Configuration" 'File'

# Specify AWS as the provider, AWS access details and a region
provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.aws_region}"
}

# Create a VPC
resource "aws_vpc" "rancher" {
  cidr_block           = "192.168.240.0/24"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags {
      Name = "${var.tag_name}-vpc"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "rancher" {
  vpc_id     = "${aws_vpc.rancher.id}"
  depends_on = ["aws_vpc.rancher"]
  tags {
      Name = "${var.tag_name}-igw"
  }
}

# Add a default route to the main route table
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.rancher.main_route_table_id}"
  depends_on             = ["aws_internet_gateway.rancher"]
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.rancher.id}"
}

# Create a Subnet
resource "aws_subnet" "rancher" {
  vpc_id                  = "${aws_vpc.rancher.id}"
  depends_on              = ["aws_vpc.rancher"]
  cidr_block              = "192.168.240.0/24"
  map_public_ip_on_launch = true
  tags {
      Name = "${var.tag_name}-subnet"
  }
}

# Create a Security Group for Rancher Infrastructure
# Inbound Ports: 22, 80, 443, 8080
# Outbound Ports: All
resource "aws_security_group" "rancher-infra" {
  name        = "${var.tag_name}-infra-sg"
  depends_on  = ["aws_vpc.rancher"]
  description = "Rancher Infrastructure Security Group"
  vpc_id      = "${aws_vpc.rancher.id}"

  # SSH from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP (8080) from anywhere
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All ports within local subnet
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["192.168.240.0/24"]
  }

  # Outbound to anywhere
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create a Security Group for Load Balancers
# Inbound Ports: 80
# Outbound Ports: All
resource "aws_security_group" "rancher-elb" {
  name        = "${var.tag_name}-elb-sg"
  depends_on  = ["aws_vpc.rancher"]
  description = "Rancher ELB Security Group"
  vpc_id      = "${aws_vpc.rancher.id}"

  # HTTP from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound to anywhere
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create Key Pair for EC2 Instances
resource "aws_key_pair" "auth" {
  key_name   = "${var.key_name}"
  public_key = "${file(var.public_key_path)}"
}

# Create the Rancher Server instance
resource "aws_instance" "rancher-server" {
  depends_on             = ["aws_security_group.rancher-infra"]
  instance_type          = "${var.instance_size}"
  ami                    = "${lookup(var.aws_amis, var.aws_region)}"
  key_name               = "${aws_key_pair.auth.id}"
  vpc_security_group_ids = ["${aws_security_group.rancher-infra.id}"]
  subnet_id              = "${aws_subnet.rancher.id}"
  private_ip             = "192.168.240.100"
  tags {
      Name = "${var.tag_name}-server"
  }
  connection {
    user     = "rancher"
    key_file = "${var.private_key_path}"
    agent    = false
  }
  provisioner "file" {
    source      = "rancher_config"
    destination = "/tmp"
  }
  provisioner "remote-exec" {
    inline = [
      "sleep 120",
      "sudo chmod -R 777 /tmp/rancher_config",
      "sudo docker run -d --restart=always -p 8080:8080 -v /tmp/rancher_config/lib/mysql:/var/lib/mysql -v /tmp/rancher_config/log/mysql:/var/log/mysql -v /tmp/rancher_config/lib/cattle:/var/lib/cattle rancher/server:v1.0.2"
    ]
  }
}

# Create the 1st Rancher Client instance
resource "aws_instance" "rancher-client-01" {
  instance_type          = "${var.instance_size}"
  ami                    = "${lookup(var.aws_amis, var.aws_region)}"
  key_name               = "${aws_key_pair.auth.id}"
  vpc_security_group_ids = ["${aws_security_group.rancher-infra.id}"]
  subnet_id              = "${aws_subnet.rancher.id}"
  private_ip             = "192.168.240.201"
  tags {
      Name = "${var.tag_name}-client-01"
  }
  connection {
    user     = "rancher"
    key_file = "${var.private_key_path}"
    agent    = false
  }
  provisioner "remote-exec" {
    inline = [
      "sleep 30",
      "sudo docker run -e CATTLE_HOST_LABELS='name=rancher-client-01' -d --privileged -v /var/run/docker.sock:/var/run/docker.sock -v /var/lib/rancher:/var/lib/rancher rancher/agent:v1.0.1 http://192.168.240.100:8080/v1/scripts/E90C4F07EF5AC0A502A8:1466118000000:3S75UjyR0EGZaYkfq21jx99kx8"
    ]
  }
}

# Create the 2nd Rancher Client instance
resource "aws_instance" "rancher-client-02" {
  instance_type          = "${var.instance_size}"
  ami                    = "${lookup(var.aws_amis, var.aws_region)}"
  key_name               = "${aws_key_pair.auth.id}"
  vpc_security_group_ids = ["${aws_security_group.rancher-infra.id}"]
  subnet_id              = "${aws_subnet.rancher.id}"
  private_ip             = "192.168.240.202"
  tags {
      Name = "${var.tag_name}-client-02"
  }
  connection {
    user     = "rancher"
    key_file = "${var.private_key_path}"
    agent    = false
  }
  provisioner "remote-exec" {
    inline = [
      "sleep 30",
      "sudo docker run -e CATTLE_HOST_LABELS='name=rancher-client-02' -d --privileged -v /var/run/docker.sock:/var/run/docker.sock -v /var/lib/rancher:/var/lib/rancher rancher/agent:v1.0.1 http://192.168.240.100:8080/v1/scripts/E90C4F07EF5AC0A502A8:1466118000000:3S75UjyR0EGZaYkfq21jx99kx8"
    ]
  }
}

# Create the 3rd Rancher Client instance
resource "aws_instance" "rancher-client-03" {
  instance_type          = "${var.instance_size}"
  ami                    = "${lookup(var.aws_amis, var.aws_region)}"
  key_name               = "${aws_key_pair.auth.id}"
  vpc_security_group_ids = ["${aws_security_group.rancher-infra.id}"]
  subnet_id              = "${aws_subnet.rancher.id}"
  private_ip             = "192.168.240.203"
  tags {
      Name = "${var.tag_name}-client-03"
  }
  connection {
    user     = "rancher"
    key_file = "${var.private_key_path}"
    agent    = false
  }
  provisioner "remote-exec" {
    inline = [
      "sleep 30",
      "sudo docker run -e CATTLE_HOST_LABELS='name=rancher-client-03' -d --privileged -v /var/run/docker.sock:/var/run/docker.sock -v /var/lib/rancher:/var/lib/rancher rancher/agent:v1.0.1 http://192.168.240.100:8080/v1/scripts/E90C4F07EF5AC0A502A8:1466118000000:3S75UjyR0EGZaYkfq21jx99kx8"
    ]
  }
}

resource "aws_elb" "rancher-elb-jenkins" {
  name            = "${var.tag_name}-elb-jenkins"
  depends_on      = ["aws_instance.rancher-client-01", "aws_instance.rancher-client-02", "aws_instance.rancher-client-03"]
  subnets         = ["${aws_subnet.rancher.id}"]
  security_groups = ["${aws_security_group.rancher-elb.id}"]
  instances       = ["${aws_instance.rancher-client-01.id}", "${aws_instance.rancher-client-02.id}", "${aws_instance.rancher-client-03.id}"]
 
  # Inbound HTTP port 80 to HTTP port 8080
  listener {
    instance_port     = 8080
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "TCP:8080"
    interval            = 10
  }
  tags {
      Name = "${var.tag_name}-elb-jenkins"
  }
}

resource "aws_elb" "rancher-elb-nagios" {
  name            = "${var.tag_name}-elb-nagios"
  depends_on      = ["aws_instance.rancher-client-01", "aws_instance.rancher-client-02", "aws_instance.rancher-client-03"]
  subnets         = ["${aws_subnet.rancher.id}"]
  security_groups = ["${aws_security_group.rancher-elb.id}"]
  instances       = ["${aws_instance.rancher-client-01.id}", "${aws_instance.rancher-client-02.id}", "${aws_instance.rancher-client-03.id}"]

  # Inbound HTTP port 80 to HTTP port 80
  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "TCP:80"
    interval            = 10
  }
  tags {
      Name = "${var.tag_name}-elb-nagios"
  }
}
