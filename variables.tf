variable "api_name" {
    type = string
}

variable "create" {
    type = bool
    default = true
}

variable "create_custom_domain" {
    type = bool
    default = true
}

variable "resources" {
    type = map(any)
    default = {}
}

variable "stage_name" {
    type = string
}

variable "custom_domain_name" {
    type = string
}

variable "custom_domain_validation_method" {
    type = string
    default = "DNS"
}

variable "custom_domain_path" {
    type = string
}