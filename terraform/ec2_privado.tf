resource "aws_instance" "instancia_toomate_privada" {
  count         = 2
  ami           = aws_ami_from_instance.ami_toomate.id
  instance_type = "t2.medium"
  key_name      = "vockey"

  subnet_id = element([
    aws_subnet.subnet_toomate_privado.id,
    aws_subnet.subnet_toomate_privado_2.id
  ], count.index)

  vpc_security_group_ids = [aws_security_group.sg_privado_tag.id]

  root_block_device {
    volume_size           = 16
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name = "Instancia privada Toomate ${count.index}"
  }
}
