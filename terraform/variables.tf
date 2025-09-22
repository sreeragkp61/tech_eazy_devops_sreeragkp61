variable "aws_region" {
  default = "ap-south-1"  # Mumbai
}

variable "ami_id" {
  default = "ami-0e1a57c5265125517"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "key_name" {
  description = "Your AWS EC2 Key Pair name"
}

variable "stage" {
  default = "dev"
}
