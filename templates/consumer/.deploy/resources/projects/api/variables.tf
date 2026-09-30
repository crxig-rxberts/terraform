variable "aws_region" {
  description = "AWS region in which to manage resources."
  type        = string
}

variable "default_tags" {
  description = "Tags applied to supported AWS resources."
  type        = map(string)
}

variable "environment" {
  description = "Deployment environment."
  type        = string
}
