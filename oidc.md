---
author: Bharath, Venna - Dell Team
company: Dell Technologies
operator: Bharath, Venna - Dell Team
---

**What is OIDC?**

OpenID Connect allows **clients (like web apps or mobile apps)** to
verify the identity of a user based on the **authentication performed by
an authorization server**, as well as to obtain basic profile
information about the user.

**�� Key Components:**

- **OAuth 2.0**: Handles **authorization** (granting access to
  resources).

- **OIDC**: Adds **authentication** (verifying who the user is).

**��️ How It Works:**

1.  **User logs in** via an identity provider (e.g., Google, Microsoft,
    Okta).

2.  The identity provider returns an **ID token** (a JWT) to the client.

3.  The client uses this token to confirm the user\'s identity and
    optionally fetch user profile info.

**\###Pre-requistes**

1.Neo4j should be having certificates and https need to be enabled 

2.Request should be logged with Okta team for the enablement and
provisioning if new scope need to be enabled .Refer RITM10126461

3.Okta team to provide all variables marked below in green for
neo4j.conf

**\###DBA to make Changes required for the neo4j.conf \####**

\##\-\-\-\-\-\-\-\-\--OIDC\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\--##  
\#dbms.security.authentication_providers=oidc-okta,ldap,native  
\#dbms.security.authorization_providers=oidc-okta,ldap,native

dbms.security.authentication_providers=oidc-okta  
dbms.security.authorization_providers=oidc-okta  
dbms.security.oidc.okta.display_name=okta  
dbms.security.oidc.okta.auth_flow=pkce  
  
dbms.security.oidc.okta.well_known_discovery_uri=dbms.security.oidc.okta.audience=0oanhf96o4ysuQY5L1d7dbms.security.oidc.okta.issuer=

  
dbms.security.oidc.okta.config=token_type_principal=id_token;token_type_authentication=id_token

dbms.security.oidc.okta.claims.username=sub  
dbms.security.oidc.okta.claims.groups=groups  
dbms.security.oidc.okta.params=client_id=0oanhf96o4ysuQY5L1d7;response_type=code;scope=openid
profile email neo4j

  
dbms.security.oidc.okta.authorization.group_to_role_mapping=
\"engineers\" = admin; \\  
                                                         
   \"neo4j_dbadmin\" = admin,reader;\\  
                                                           
 \"collaborators\" = reader

  
\##\-\-\-\-\-\-\-\-\-\-\-\--Vendor
recommendation\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\--###  
dbms.security.logs.oidc.jwt_claims_at_debug_level_enabled=true  
dbms.logs.security.level=DEBUG

  
internal.server.bolt.unauth_max_inbound_bytes=163840

\##\-\-\-\-\-\-\-\-\--OIDC\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\-\--##

**\###Configure groups dynamically \####**

CALL
dbms.setConfigValue(\'dbms.security.oidc.okta.authorization.group_to_role_mapping\',\'\"engineers\"
= admin;\"neo4j_dbadmin\" = admin,reader;\"mopsmgrprd_readonly\" =
reader;\"mopsmgrnp_useradm\" = reader;\"collaborators\" = reader\');

**\###List the roles defined for OIDC**

CALL dbms.listConfig() YIELD name, value WHERE name CONTAINS \"oidc\"
RETURN name,value;

**\###How to Connect neo4j using Single Sign On using Okta **

Connect browser url for neo4j using https ://servername:port\>\> Change
authentication \>\>Select Single Sign On \>\>Click Okta \>\>User will be
redirected to Okta and seamless login should happen

**\###Troubleshoot Okta SSO **

1.Open google chrome \>\>Enable Developer Options (Ctrl+Shift+I)
\>\>Select Network \>\>Add a filter to include only \"token\" \>\>

2.Connect browser url for neo4j using https ://servername:port\>\>
Change authentication \>\>Select Single Sign On \>\>Click Okta \>\>User
will be redirected to Okta and seamless login should happen

3.Once Okta connected \>\>Validate neo4j roles \>\>User should have
assigned roles (Example admin ,reader is available)

4.With Developer tools enabled  \>\>Go to Network \>\>Select token
\>\>Go to preview \>\>select \'id_token\' \>\>Right click \>\>Copy
value 

5.Open in browser  and input the values received from Step:4 and
validate the json web token data \>\>User will be provisioned roles if
they are part of the \"groups \"

6.Open neo4j server -debug.log and validate the logs for further
troubleshooting
