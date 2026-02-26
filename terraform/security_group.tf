resource "aws_security_group" "sg_ssh" {
    name = "sg_ssh"
    description = "Security group for SSH access"
    vpc_id = "vpc-08fe1523d8dfe8c10"


    ingress {
        description = "Allow SSH access"
        from_port = var.porta_ssh
        to_port = var.porta_ssh
        protocol = "tcp"
        cidr_blocks =   var.ip_qualquer
        ipv6_cidr_blocks = var.ipv6_qualquer
}

egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = var.ip_qualquer
    ipv6_cidr_blocks = var.ipv6_qualquer
}

tags = {
  Name = "aaaaaaaa"
}

}