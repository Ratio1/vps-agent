# Contabo Instructions

```bash
CLIENT_ID=<ClientId from Customer Control Panel>
CLIENT_SECRET=<ClientSecret from Customer Control Panel>
API_USER=<API User from Customer Control Panel>
API_PASSWORD='<API Password from Customer Control Panel>'
REQUEST_ID="$(node -e "console.log(require('crypto').randomUUID())")"

ACCESS_TOKEN=$(curl -fsS \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  --data-urlencode "username=$API_USER" \
  --data-urlencode "password=$API_PASSWORD" \
  -d 'grant_type=password' \
  'https://auth.contabo.com/auth/realms/contabo/protocol/openid-connect/token' \
  | jq -r '.access_token')

curl -fsS \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "x-request-id: $REQUEST_ID" \
  "https://api.contabo.com/v1/compute/instances" \
  | jq
```
