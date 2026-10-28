variable "project_id" {
  description = "The ID of the project in which to create resources."
  type        = string
  default     = "humainos-dev0"
}

variable "region" {
  description = "The default region for resources."
  type        = string
  default     = "us-central1"
}

variable "labels" {
  description = "Labels to apply to all created resources."
  type        = map(string)
  default = {
    purpose = "devsecops-step8-test"
  }
}
