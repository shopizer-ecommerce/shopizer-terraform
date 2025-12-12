terraform {
  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = "~> 5.3.0"
    }
  }
}

############################################
# 1️⃣  Lookup the built-in clients
############################################

# realm-management client (contains admin roles)
data "keycloak_openid_client" "realm_management" {
  realm_id  = keycloak_realm.shopizer_realm.id
  client_id = "realm-management"
}

# account client (contains end-user roles)
data "keycloak_openid_client" "account" {
  realm_id  = keycloak_realm.shopizer_realm.id
  client_id = "account"
}


############################################
# 2️⃣  Lookup the existing roles you need
############################################

data "keycloak_role" "manage_users" {
  realm_id  = keycloak_realm.shopizer_realm.id
  client_id = data.keycloak_openid_client.realm_management.id
  name      = "manage-users"
}

data "keycloak_role" "query_users" {
  realm_id  = keycloak_realm.shopizer_realm.id
  client_id = data.keycloak_openid_client.realm_management.id
  name      = "query-users"
}

data "keycloak_role" "view_profile" {
  realm_id  = keycloak_realm.shopizer_realm.id
  client_id = data.keycloak_openid_client.account.id
  name      = "view-profile"
}

# --------------------------------------------------
# Generate random client secret
# --------------------------------------------------
resource "random_password" "shopizer_client_secret" {
  length = 32
  lower  = true
  upper  = true
  numeric = true
  special = false
}


resource "random_id" "shopizer_client_suffix" {
  byte_length = 4
}

provider "keycloak" {
  client_id     = "admin-cli"
  url           = var.keycloak_url
  username      = var.keycloak_username
  password      = var.keycloak_password
  realm         = "master"
}

# 1. Realm


# -------------------------
# Realm definition
# -------------------------
resource "keycloak_realm" "shopizer_realm" {
  realm                     = var.realm_name
  display_name              = var.realm_name
  enabled                   = true

  login_with_email_allowed       = true
  registration_email_as_username = true
  duplicate_emails_allowed       = false
  edit_username_allowed          = true
  login_theme                    = "shopizer"
}

# -------------------------
# Client definition for backend (service account)
# -------------------------
resource "keycloak_openid_client" "shopizer_client" {
  realm_id                     = keycloak_realm.shopizer_realm.id
  client_id                    = var.client_id
  name                         = var.client_name
  enabled                      = true
  access_type                  = "CONFIDENTIAL"
  standard_flow_enabled         = true
  direct_access_grants_enabled  = true
  implicit_flow_enabled         = true
  #pkce_code_challenge_method    = "S256"
  # allow to use client admin
  service_accounts_enabled      = true

  valid_redirect_uris = ["*"]
  web_origins         = ["*"]

  # Auto-generated secret
  client_secret = random_password.shopizer_client_secret.result
}

resource "keycloak_openid_client" "shopizer_spa_client" {
  realm_id                      = keycloak_realm.shopizer_realm.id
  client_id                     = "${var.client_id}-spa"  # e.g. shopizer-spa
  name                          = "${var.client_name} SPA"
  enabled                       = true

  access_type                   = "PUBLIC"
  standard_flow_enabled         = true
  implicit_flow_enabled         = false
  direct_access_grants_enabled  = false

  pkce_code_challenge_method    = "S256"

  # This is the test react admin
  valid_redirect_uris = [
    "http://localhost:5173/*"
  ]

  web_origins = [
    "http://localhost:5173"
  ]
}




# -------------------------
# Custom User Profile
# -------------------------

resource "keycloak_realm_user_profile" "shopizer_user_profile" {
  realm_id = keycloak_realm.shopizer_realm.id

  attribute {
    name         = "username"
    display_name = "Username"
  }

  attribute {
    name         = "firstName"
    display_name = "First Name"

    permissions {
      view = ["user", "admin"]
      edit = ["user", "admin"]
    }
  }

  attribute {
    name         = "lastName"
    display_name = "Last Name"

    permissions {
      view = ["user", "admin"]
      edit = ["user", "admin"]
    }
  }

  attribute {
    name = "email"

    permissions {
      view = ["admin"]
      edit = ["admin"]
    }
  }

  attribute {
    name         = "org"
    display_name = "org"

    permissions {
      view = ["admin"]
      edit = ["admin"]
    }
  }

}

resource "keycloak_openid_client_default_scopes" "client_default_scopes" {
  realm_id              = keycloak_realm.shopizer_realm.id
  client_id             = keycloak_openid_client.shopizer_client.id

  default_scopes = [
    "profile",
    "email",
    "roles",
    "web-origins"
  ]

  depends_on = [
    keycloak_openid_client.shopizer_client
  ]
}

# 3. Client Scopes
# Create realm roles
resource "keycloak_openid_client_scope" "read" {
  realm_id = keycloak_realm.shopizer_realm.id
  name     = "read"
  depends_on = [
    keycloak_openid_client.shopizer_client
  ]
}

resource "keycloak_openid_client_scope" "write" {
  realm_id = keycloak_realm.shopizer_realm.id
  name     = "write"
  depends_on = [
    keycloak_openid_client.shopizer_client
  ]
}

resource "keycloak_openid_client_scope" "admin" {
  realm_id = keycloak_realm.shopizer_realm.id
  name     = "admin"
  depends_on = [
    keycloak_openid_client.shopizer_client
  ]
}

# 4. Realm Roles

resource "keycloak_role" "admin_role" {
  realm_id = keycloak_realm.shopizer_realm.id
  name     = "admin"
}

resource "keycloak_role" "user_role" {
  realm_id = keycloak_realm.shopizer_realm.id
  name     = "user"
}

resource "keycloak_role" "superadmin_role" {
  realm_id = keycloak_realm.shopizer_realm.id
  name     = "superadmin"
}

# 4. Client Roles
#resource "keycloak_role" "user_role" {
#  realm_id  = keycloak_realm.shopizer_realm.id
#  client_id = keycloak_openid_client.shopizer_client.id
#  name      = "user"
#  depends_on = [
#    keycloak_openid_client.shopizer_client
#  ]
#}

#resource "keycloak_role" "admin_role" {
#  realm_id  = keycloak_realm.shopizer_realm.id
#  client_id = keycloak_openid_client.shopizer_client.id
#  name      = "admin"
#  depends_on = [
#    keycloak_openid_client.shopizer_client
#  ]
#}

#resource "keycloak_role" "superadmin_role" {
#  realm_id  = keycloak_realm.shopizer_realm.id
#  client_id = keycloak_openid_client.shopizer_client.id
#  name      = "superadmin"
#  depends_on = [
#    keycloak_openid_client.shopizer_client
#  ]
#}

# --------------------------------------------------
# Attach optional scopes
# --------------------------------------------------
resource "keycloak_openid_client_optional_scopes" "shopizer_client_optionals" {
  realm_id  = keycloak_realm.shopizer_realm.id
  client_id = keycloak_openid_client.shopizer_client.id

  optional_scopes = [
    keycloak_openid_client_scope.admin.name,
    keycloak_openid_client_scope.read.name,
    keycloak_openid_client_scope.write.name
  ]
}

resource "keycloak_openid_user_attribute_protocol_mapper" "org_mapper" {
  realm_id  = keycloak_realm.shopizer_realm.id
  client_id = keycloak_openid_client.shopizer_client.id

  name                 = "org"
  user_attribute       = "org"
  claim_name           = "org"
  claim_value_type     = "String"

  add_to_id_token      = true
  add_to_access_token  = true
  add_to_userinfo      = true
}

# Output the generated client_id
output "shopizer_client_id" {
  description = "The generated Keycloak client_id for the Shopizer client"
  value       = keycloak_openid_client.shopizer_client.client_id
}

# Output the Keycloak internal UUID (optional)
output "shopizer_client_internal_id" {
  description = "The internal Keycloak resource ID (UUID) for the client"
  value       = keycloak_openid_client.shopizer_client.id
}

output "shopizer_client_secret" {
  description = "The generated client_secret for the Shopizer client"
  value       = random_password.shopizer_client_secret.result
  sensitive   = true
}

############################################
# 3️⃣  Assign those roles to your service account
############################################

resource "keycloak_openid_client_service_account_role" "manage_users_role_assignment_1" {
    realm_id                = keycloak_realm.shopizer_realm.id
    service_account_user_id = keycloak_openid_client.shopizer_client.service_account_user_id
    depends_on = [
      keycloak_openid_client.shopizer_client
      
    ]
    client_id               = data.keycloak_openid_client.realm_management.id
    role                    = "manage-users"
}

resource "keycloak_openid_client_service_account_role" "manage_users_role_assignment_2" {
    realm_id                = keycloak_realm.shopizer_realm.id
    service_account_user_id = keycloak_openid_client.shopizer_client.service_account_user_id
    depends_on = [
      keycloak_openid_client.shopizer_client
      
    ]
    client_id               = data.keycloak_openid_client.realm_management.id
    role                    = "query-users"
}


