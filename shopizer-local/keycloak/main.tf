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

  # Allow login with email instead of username
  login_with_email_allowed = true
  registration_email_as_username = true
  duplicate_emails_allowed = false
  edit_username_allowed = true

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
  service_accounts_enabled = false
  client_secret         = var.client_secret
}

#resource "keycloak_realm_user_profile" "shopizer_user_profile" {
#  realm_id = keycloak_realm.shopizer_realm.id

#  #Organization attribute
#  attribute {
#    name         = "org"
#    display_name = "Organization"

#    validator {
#      name = "length"
#      config = {
#        min = "1"
#        max = "255"
#      }
#    }
#  }

#  # Email attribute
#  attribute {
#    name         = "email"
#    display_name = "Email"

#    validator {
#      name = "email"
#    }
#  }

#  # First name
#  attribute {
#    name         = "firstName"
#    display_name = "First Name"

#    validator {
#      name = "length"
#      config = {
#        min = "1"
#        max = "255"
#      }
#    }
#  }

#  # Last name
#  attribute {
#    name         = "lastName"
#    display_name = "Last Name"

#    validator {
#      name = "length"
#      config = {
#        min = "1"
#        max = "255"
#      }
#    }
#  }

#  # Username
#  attribute {
#    name         = "username"
#    display_name = "Username"

#    validator {
#      name = "length"
#      config = {
#        min = "3"
#        max = "50"
#      }
#    }
#  }
#}


# 3. Client Scopes
# Create realm roles
resource "keycloak_openid_client_scope" "read" {
  realm_id = keycloak_realm.shopizer_realm.id
  name     = "read"
}

resource "keycloak_openid_client_scope" "write" {
  realm_id = keycloak_realm.shopizer_realm.id
  name     = "write"
}

resource "keycloak_openid_client_scope" "admin" {
  realm_id = keycloak_realm.shopizer_realm.id
  name     = "admin"
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

resource "keycloak_openid_client_default_scopes" "shopizer_default_scopes" {
  realm_id  = keycloak_realm.shopizer_realm.id
  client_id = keycloak_openid_client.shopizer_client.id

  default_scopes = [
    "profile",
    "email",
    keycloak_openid_client_scope.read.name,
    keycloak_openid_client_scope.write.name,
    keycloak_openid_client_scope.admin.name,
  ]
}

# 5. User
#resource "keycloak_user" "admin_user" {
#  realm_id       = keycloak_realm.shopizer_realm.id
#  username       = var.admin_username
#  email          = var.admin_username
#  enabled        = true
#  email_verified = true

#  initial_password {
#    value     = var.admin_password
#    temporary = false
#  }
#}

# 6. Assign Role(s) to User
#resource "keycloak_user_roles" "admin_user_roles" {
#  realm_id = keycloak_realm.shopizer_realm.id
#  user_id  = keycloak_user.admin_user.id

#  role_ids = [
#    keycloak_role.superadmin_role.id,
#  ]
#}
