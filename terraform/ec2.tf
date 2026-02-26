resource "aws_instance" "instancia_iac02" {
    ami= "ami-0b6c6ebed2801a5cb"
    instance_type = "t3.micro"
    key_name = "vockey"

    vpc_security_group_ids = [aws_security_group.sg_ssh.id]

    tags = {
      Name = "Instancia"
    }

    ebs_block_device {
      device_name = "/dev/sda1"
      volume_size = 67
      volume_type = "gp3"
    }

    user_data = file("scripts/instalar_java.sh")

    
}