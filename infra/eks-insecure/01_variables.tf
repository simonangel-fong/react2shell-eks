# variable.tf

variable "alert_email" {
  description = "Email that receives GuardDuty alert notifications (SNS subscription). Set in terraform.tfvars."
  type        = string
}
