Delete shopizer realm by hand
terraform init
terraform plan -var-file variables.tfvars
terraform apply -var-file variables.tfvars
terraform destroy -var-file variables.tfvars

#TODO
To have admin api woking in user pod, enable service account roles in capability
add service account role
map service account roles in client
realm-managementmanage-users	False	role_manage-users	
realm-managementquery-users		False	role_query-users	
accountview-profile				False	role_view-profile
