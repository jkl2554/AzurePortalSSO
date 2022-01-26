# SSO 용 Redirection URL 생성
## 사전 요구사항  
- Azure CLI사용
- AD 권한 필요(Global admin. or Application Admin.)

## 변수 설정  

```s
Tenant='your.onmicrosoft.com' # 테넌트 ID or url
DOMAIN='keycloak.koreacentral.cloudapp.azure.com' # 도메인
```
## App 생성
```s
AppID=$(az ad app create --display-name "My Tenant Azure Portal redirect app" \
                --reply-urls https://portal.azure.com/$Tenant/ --query appId -o tsv )
```
## App 에 API 권한 추가
```s
## Graph API 권한 추가
# User.Read 권한
az ad app permission add --id $AppID \
                        --api 00000003-0000-0000-c000-000000000000 \
                        --api-permissions e1fe6dd8-ba31-4d61-89e7-88639da4683d=Scope
# openid 권한
az ad app permission add --id $AppID \
                        --api 00000003-0000-0000-c000-000000000000 \
                        --api-permissions 37f7f235-527c-4136-accd-4a02d197296e=Scope
# email 권한
az ad app permission add --id $AppID \
                        --api 00000003-0000-0000-c000-000000000000 \
                        --api-permissions 64a6cdd6-aab1-4aaf-94b8-3cc8405e90d0=Scope
# profile 권한
az ad app permission add --id $AppID \
                        --api 00000003-0000-0000-c000-000000000000 \
                        --api-permissions 14dad69e-099b-42c9-810b-d002981feec1=Scope

# Grant admin consent 수행
az ad app permission admin-consent --id $AppID
```
## Redirection URL 생성
```s
# Redirection URL
echo "https://login.microsoftonline.com/hyugo.onmicrosoft.com/oauth2/v2.0/authorize?client_id=$AppID&response_type=code&scope=https%3A%2F%2Fmanagement.core.windows.net%2F%2Fuser_impersonation+openid+email+profile&redirect_uri=https%3A%2F%2Fportal.azure.com%2F$Tenant%2F&domain_hint=keycloak2.koreacentral.cloudapp.azure.com"
```
*참고 문서  
https://docs.microsoft.com/ko-kr/azure/active-directory/develop/v2-oauth2-implicit-grant-flow  
https://docs.microsoft.com/ko-kr/azure/active-directory/develop/v2-protocols-oidc