variable "ami" {
  type    = string
  default = "ami-0c65adc9a5c1b5d7c"
}
variable "bucket_name" {
  type    = string
  default = "jenkins-artifacts-1024"
}
variable "aws_region" {
  type    = string
  default = "us-west-2"
}
variable "instance_type" {
  type    = string
  default = "t2.small"
}
variable "key_pair" {
  type    = string
  default = "jenkins_key"
}
variable "my_ip" {
  type      = string
  default   = " "
  sensitive = true
}
