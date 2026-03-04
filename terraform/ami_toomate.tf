resource "aws_ami_from_instance" "ami_toomate" {
  name               = "ami-toomate-docker"
  source_instance_id = aws_instance.builder_toomate.id

  depends_on = [null_resource.wait_for_build]

  tags = {
    Name = "ami-toomate-docker"
  }
}