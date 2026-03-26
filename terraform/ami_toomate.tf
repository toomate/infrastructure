resource "aws_ami_from_instance" "ami_toomate" {
  name               = "ami-toomate-docker"
  source_instance_id = aws_instance.builder_toomate.id  

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [terraform_data.wait_for_build]

  tags = {
    Name = "ami-toomate-docker"
  }
}