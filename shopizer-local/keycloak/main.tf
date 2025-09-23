terraform {
  required_providers {
    keycloak = {
      source  = "mrparkers/keycloak"
      version = ">= 4.4.0"
    }
  }
}

provider "keycloak" {
  client_id = "admin-cli"
  username  = var.keycloak_username
  password  = var.keycloak_password
  url       = var.keycloak_url
  realm     = "master"
}

# 1. Realm
resource "keycloak_realm" "shopizer_realm" {
  realm   = var.realm_name
  enabled = true

  attributes = {
    org = "string"
  }
}

# 2. Client
resource "keycloak_openid_client" "shopizer_client" {
  realm_id              = keycloak_realm.shopizer_realm.id
  client_id             = var.client_id
  name                  = var.client_name
  enabled               = true
  access_type           = "CONFIDENTIAL"
  standard_flow_enabled = true
  direct_access_grants_enabled = true
  implicit_flow_enabled = true
  valid_redirect_uris   = ["*"]
  web_origins           = ["*"]
  service_accounts_enabled = true
  client_secret         = var.client_secret
}

# 3. Client Scopes

resource "keycloak_openid_client_scope" "admin_scope" {
  realm_id = keycloak_realm.shopizer_realm.id
  name     = "admin"
}

resource "keycloak_openid_client_scope" "read_scope" {
  realm_id = keycloak_realm.shopizer_realm.id
  name     = "read"
}

resource "keycloak_openid_client_scope" "write_scope" {
  realm_id = keycloak_realm.shopizer_realm.id
  name     = "write"
}

resource "keycloak_openid_client_default_scopes" "shopizer_client_scopes" {
  realm_id  = keycloak_realm.shopizer_realm.id
  client_id = keycloak_openid_client.shopizer_client.id

  default_scopes = [
    keycloak_openid_client_scope.admin_scope.name,
    keycloak_openid_client_scope.read_scope.name,
    keycloak_openid_client_scope.write_scope.name,
  ]
}

# 4. Roles
resource "keycloak_role" "admin_role" {
  realm_id  = keycloak_realm.shopizer_realm.id
  client_id = keycloak_openid_client.shopizer_client.id
  name      = "admin"
}

resource "keycloak_role" "superadmin_role" {
  realm_id  = keycloak_realm.shopizer_realm.id
  client_id = keycloak_openid_client.shopizer_client.id
  name      = "superadmin"
}

# 5. User
resource "keycloak_user" "admin_user" {
  realm_id       = keycloak_realm.shopizer_realm.id
  username       = var.admin_username
  email          = var.admin_username
  enabled        = true
  email_verified = true

  initial_password {
    value     = var.admin_password
    temporary = false
  }
}

# 6. Assign Role(s) to User
resource "keycloak_user_roles" "admin_user_roles" {
  realm_id = keycloak_realm.shopizer_realm.id
  user_id  = keycloak_user.admin_user.id

  role_ids = [
    keycloak_role.superadmin_role.id,
  ]
}
