Delete shopizer realm by hand
terraform init
terraform plan -var-file variables.tfvars
terraform apply -var-file variables.tfvars
terraform destroy -var-file variables.tfvars

#TODO Realm Roles are not created

#TODO user profile cannot play with default attributes structure

#TODO
missing client scopes
Add roles
	roles	OpenID Connect	OpenID Connect scope for add user roles to the access token
	acr	OpenID Connect	OpenID Connect scope for add acr (authentication context class reference) to the token
	web-origins	OpenID Connect	OpenID Connect scope for add allowed web origins to the access token
	basic	OpenID Connect	OpenID Connect scope for add all basic claims to the token


map org attribute

Client scopes -> profile -> mappers -> add mapping

User attribute
name org
User attribute org
Claim name org
add to id token
add to access token
