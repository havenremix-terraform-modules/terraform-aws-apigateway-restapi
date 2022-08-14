terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 4.26"
            configuration_aliases = [aws.us-east-1]
        }
    }
}

#MAIN API
resource "aws_api_gateway_rest_api" "this" {
    count = var.create ? 1 : 0

    name = var.api_name
}

#ACM CERTIFICATE FOR CUSTOM DOMAIN
resource "aws_acm_certificate" "api_domain_certificate" {
    count = var.create && var.create_custom_domain && var.custom_domain_name != "" ? 1 : 0

    provider = aws.us-east-1

    domain_name = var.custom_domain_name
    validation_method = var.custom_domain_validation_method
}

#ACM CERTIFICATE VALIDATION FOR CUSTOM DOMAIN
resource "aws_acm_certificate_validation" "api_domain_certificate_validation" {
    count = var.create && var.create_custom_domain && var.custom_domain_name != "" ? 1 : 0
    
    provider = aws.us-east-1

    certificate_arn = aws_acm_certificate.api_domain_certificate[0].arn
}

#CUSTOM DOMAIN
resource "aws_api_gateway_domain_name" "api_domain" {
    count = var.create && var.create_custom_domain && var.custom_domain_name != "" ? 1 : 0
    
    certificate_arn = aws_acm_certificate_validation.api_domain_certificate_validation[0].certificate_arn
    domain_name = var.custom_domain_name
}

#BASE PATH MAPPING FOR CUSTOM DOMAIN
resource "aws_api_gateway_base_path_mapping" "api_domain_base_path_mapping" {
    count = var.create && var.create_custom_domain && var.custom_domain_name != "" ? 1 : 0

    api_id = aws_api_gateway_rest_api.this[0].id
    stage_name = aws_api_gateway_stage.stage[0].stage_name
    domain_name = aws_api_gateway_domain_name.api_domain[0].domain_name
    base_path = var.custom_domain_path
}

#RESOURCES
resource "aws_api_gateway_resource" "resource" {
    for_each = var.create ? var.resources : {}

    rest_api_id = aws_api_gateway_rest_api.this[0].id
    parent_id = aws_api_gateway_rest_api.this[0].root_resource_id
    path_part = each.value["path"]
}

#METHODS
resource "aws_api_gateway_method" "method" {
    for_each = var.create ? var.resources : {}

    rest_api_id = aws_api_gateway_rest_api.this[0].id
    resource_id = aws_api_gateway_resource.resource[each.key].id
    http_method = var.resources[each.key]["method"]
    authorization = "NONE"
}

#LAMBDA INTEGRATIONS
resource "aws_api_gateway_integration" "integration" {
    for_each = var.create ? var.resources : {}

    rest_api_id = aws_api_gateway_rest_api.this[0].id
    resource_id = aws_api_gateway_resource.resource[each.key].id
    http_method = aws_api_gateway_method.method[each.key].http_method
    integration_http_method = var.resources[each.key]["method"]
    type = "AWS_PROXY"
    uri = var.resources[each.key]["integration"]
}

#INTEGRATION RESPONSES
resource "aws_api_gateway_integration_response" "response" {
    for_each = var.create ? var.resources : {}

    rest_api_id = aws_api_gateway_rest_api.this[0].id
    resource_id = aws_api_gateway_resource.resource[each.key].id
    http_method = aws_api_gateway_method.method[each.key].http_method
    status_code = aws_api_gateway_method_response.response_200[each.key].status_code

    response_templates = {
        "application/json" = ""
    }
}

#METHOD RESPONSES
resource "aws_api_gateway_method_response" "response_200" {
    for_each = var.create ? var.resources : {}

    rest_api_id = aws_api_gateway_rest_api.this[0].id
    resource_id = aws_api_gateway_resource.resource[each.key].id
    http_method = aws_api_gateway_method.method[each.key].http_method
    status_code = "200"

    response_models = {
        "application/json" = "Empty"
    }
}

#DEPLOYMENT
resource "aws_api_gateway_deployment" "deployment" {
    count = var.create ? 1 : 0
    
    rest_api_id = aws_api_gateway_rest_api.this[0].id
}

#STAGE
resource "aws_api_gateway_stage" "stage" {
    count = var.create ? 1 : 0
    
    deployment_id = aws_api_gateway_deployment.deployment[0].id
    rest_api_id = aws_api_gateway_rest_api.this[0].id

    stage_name = var.stage_name
}