resource "aws_vpc" "vpc" {
  cidr_block = "10.2.0.0/16"

  tags {
    Name = "test_vpc"
  }
}
