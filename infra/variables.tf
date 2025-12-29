variable "project_name" {
  type        = string
  description = "Application short name, e.g., cashburn-starter-tf"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "The project name must be lowercase letters, numbers, or hyphens only."
  }
}

## Set this variable with the environments you want to create! ##
variable "env" {
  type        = string
  description = "Environment, ex. dev, test, prod"
  validation {
    condition     = contains(["dev", "test", "stage", "prod"], var.env)
    error_message = "The environment must be one of: dev, test, prod."
  }
}

variable "location" {
  type    = string
  default = "centralus"
}
