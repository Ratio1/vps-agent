CLIENT_ID=<ClientId from Customer Control Panel>
CLIENT_SECRET=<ClientSecret from Customer Control Panel>
API_USER=<API User from Customer Control Panel>
API_PASSWORD='<API Password from Customer Control Panel>'
ACCESS_TOKEN=$(curl -d "client_id=$CLIENT_ID" -d "client_secret=$CLIENT_SECRET" --data-urlencode "username=$API_USER" --data-urlencode "password=$API_PASSWORD" -d 'grant_type=password' 'https://auth.contabo.com/auth/realms/contabo/protocol/openid-connect/token' | jq -r '.access_token')
# get list of your instances
curl -X GET -H "Authorization: Bearer $ACCESS_TOKEN" -H "x-request-id: 51A87ECD-754E-4104-9C54-D01AD0F83406" "https://api.contabo.com/v1/compute/instances" | jq