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

############################################
####### DOMAIN AND BASE PATH MAPPING #######
############################################

resource "aws_api_gateway_domain_name" "api_domain" {
    count = var.create && var.create_custom_domain && var.custom_domain_name != "" ? 1 : 0

    certificate_arn = var.custom_domain_certificate_arn
    domain_name = var.custom_domain_name
}

resource "aws_api_gateway_base_path_mapping" "api_domain_base_path_mapping" {
    count = var.create && var.create_custom_domain && var.custom_domain_name != "" ? 1 : 0

    api_id = aws_api_gateway_rest_api.this[0].id
    stage_name = aws_api_gateway_stage.stage[0].stage_name
    domain_name = aws_api_gateway_domain_name.api_domain[0].domain_name
    base_path = var.custom_domain_path
}

#########################
####### RESOURCES #######
#########################

resource "aws_api_gateway_resource" "resource" {
    for_each = var.create ? var.resources : {}

    rest_api_id = aws_api_gateway_rest_api.this[0].id
    parent_id = aws_api_gateway_rest_api.this[0].root_resource_id
    path_part = each.value["path"]
}

#######################
####### METHODS #######
#######################

resource "aws_api_gateway_method" "method" {
    for_each = var.create ? var.resources : {}

    rest_api_id = aws_api_gateway_rest_api.this[0].id
    resource_id = aws_api_gateway_resource.resource[each.key].id
    http_method = var.resources[each.key]["method"]
    authorization = var.cognito_authorizer_user_pool_arn != "" ? var.resources[each.key]["authorization"] : "NONE"
    authorizer_id = aws_api_gateway_authorizer.cognito_authorizer[0].id

    authorization_scopes = var.resources[each.key]["authorization_scopes"]

    depends_on = [
        aws_api_gateway_authorizer.cognito_authorizer
    ]
}

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

############################
####### INTEGRATIONS #######
############################

resource "aws_api_gateway_integration" "lambda_integration" {
    for_each = var.create ? var.resources : {}

    rest_api_id = aws_api_gateway_rest_api.this[0].id
    resource_id = aws_api_gateway_resource.resource[each.key].id
    http_method = aws_api_gateway_method.method[each.key].http_method
    integration_http_method = "POST"
    type = "AWS_PROXY"
    content_handling = "CONVERT_TO_TEXT"
    uri = var.resources[each.key]["integration"]
}

resource "aws_lambda_permission" "lambda_permission" {
    for_each = var.create ? var.resources : {}

    statement_id = "AllowLambdaExecutionFromAPIGateway"
    action = "lambda:InvokeFunction"
    function_name = var.resources[each.key]["function_name"]
    principal = "apigateway.amazonaws.com"
    source_arn = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.this[0].id}/*/${var.resources[each.key]["method"]}/${var.resources[each.key]["path"]}"
}

resource "aws_api_gateway_integration_response" "response" {
    for_each = var.create ? var.resources : {}

    rest_api_id = aws_api_gateway_rest_api.this[0].id
    resource_id = aws_api_gateway_resource.resource[each.key].id
    http_method = aws_api_gateway_method.method[each.key].http_method
    status_code = aws_api_gateway_method_response.response_200[each.key].status_code
}

###########################
####### AUTHORIZERS #######
###########################

resource "aws_api_gateway_authorizer" "cognito_authorizer" {
    count = var.create && var.cognito_authorizer_user_pool_arn != "" ? 1 : 0
    name = "CognitoAuthorizer"
    rest_api_id = aws_api_gateway_rest_api.this[0].id
    type = "COGNITO_USER_POOLS"
    provider_arns = var.cognito_authorizer_user_pool_arn
}

######################################
####### STAGING AND DEPLOYMENT #######
######################################

resource "aws_api_gateway_stage" "stage" {
    count = var.create ? 1 : 0
    
    deployment_id = aws_api_gateway_deployment.deployment[0].id
    rest_api_id = aws_api_gateway_rest_api.this[0].id
    stage_name = var.stage_name
}

resource "aws_api_gateway_deployment" "deployment" {
    count = var.create ? 1 : 0
    
    rest_api_id = aws_api_gateway_rest_api.this[0].id

    depends_on = [
        aws_api_gateway_method.method
    ]
}