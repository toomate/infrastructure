resource "aws_instance" "instancia_toomate_privada" {
  ami           = "ami-0b6c6ebed2801a5cb"
  instance_type = "t2.medium"
  key_name      = "vockey"

  subnet_id = aws_subnet.subnet_toomate_privado.id
  vpc_security_group_ids = [aws_security_group.sg_privado_tag.id]

  tags = {
    Name = "Instancia privada Toomate"
  }

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 16
    volume_type = "gp3"
  }
}
