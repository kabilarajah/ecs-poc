variable "aws_region" {
  description = "The AWS region to deploy into"
  type        = string
  default     = "us-east-1" 
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "weather-app"
}