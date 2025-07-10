variable "app_name" {
  description = "Application name"
  type        = string
  default     = "nginx-hello-world"
}

variable "domain_name" {
  description = "Domain name for Route53"
  type        = string
  default     = "hello.localstack.cloud"
}

variable "container_port" {
  description = "Port exposed by the container"
  type        = number
  default     = 80
}

variable "cpu" {
  description = "Fargate instance CPU units"
  type        = string
  default     = "256"
}

variable "memory" {
  description = "Fargate instance memory in MiB"
  type        = string
  default     = "512"
}

variable "desired_count" {
  description = "Number of ECS tasks to run"
  type        = number
  default     = 2
}