variable "region" {
  description = "AWS region"
  type        = string
}

variable "app_name" {
  description = "Application name"
  type        = string
}

variable "container_port" {
  description = "Port exposed by the container"
  type        = number
}

variable "cpu" {
  description = "Fargate instance CPU units"
  type        = string
}

variable "memory" {
  description = "Fargate instance memory in MiB"
  type        = string
}

variable "desired_count" {
  description = "Number of ECS tasks to run"
  type        = number
}