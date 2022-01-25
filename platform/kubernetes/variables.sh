####### variables #####

INGRESS_CLASS='nginx'

# EMAIL_ADDR='your@email.org' -> issuer생성 시 입력받음
KEYCLOAK_ADMIN='admin'
KEYCLOAK_PASSWORD='qwer1234!@#$'

DNS_LABEL='keycloak'
DOMAIN="$DNS_LABEL.koreacentral.cloudapp.azure.com" ## 사용자 지정 도메인 사용 시 직접 입력
