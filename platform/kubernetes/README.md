# kubernetes에 배포  

## 사전 요구사항
- kubectl 설치 필요: snap install kubectl --classic
- helm 3.x 설치 필요: sudo snap install helm --classic  
- 쿠버네티스 연결 필요

## 배포 스크립트 사용
[helm_deploy.sh](./helm_deploy.sh) 파일을 통해 배포 가능, 변수 변경 필요


## 변수 설정

```s
INGRESS_CLASS='nginx'

EMAIL_ADDR='your@email.org'
KEYCLOAK_ADMIN='admin'
KEYCLOAK_PASSWORD='qwer1234!@#$'

DNS_LABEL='keycloak'
DOMAIN="$DNS_LABEL.koreacentral.cloudapp.azure.com" ## 사용자 지정 도메인 사용 시 직접 입력
```
## 네임스페이스 배포
```s
# Create a namespace for deployment
kubectl create ns keycloak
```
## 인그레스 컨트롤러 설치
```s
############## ingress #########################
# Add the ingress-nginx repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

# Use Helm to deploy an NGINX ingress controller
## 사용자 지정 도메인 사용 시 --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-dns-label-name"="$DNS_LABEL" 줄 제거
helm install nginx-ingress ingress-nginx/ingress-nginx \
    --namespace keycloak \
    --set controller.replicaCount=1 \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-dns-label-name"="$DNS_LABEL"  \
    --set controller.ingressClass=$INGRESS_CLASS

```
## lets encrypt 인증서 발급을 위해 cert manager 설치
```s
################# cert manager #####################

# Label the ingress-basic namespace to disable resource validation
kubectl label namespace keycloak cert-manager.io/disable-validation=true

# Add the Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io

# Update your local Helm chart repository cache
helm repo update

# Install the cert-manager Helm chart
helm install cert-manager jetstack/cert-manager \
                --namespace keycloak \
                --version v0.16.1 \
                --set installCRDs=true \
                --set nodeSelector."kubernetes\.io/os"=linux \
                --set webhook.nodeSelector."kubernetes\.io/os"=linux \
                --set cainjector.nodeSelector."kubernetes\.io/os"=linux 
```

## 인증서 발급용 issuer생성
```s
#issuer 생성
cat <<EOF | kubectl apply -f - 
apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: $EMAIL_ADDR
    privateKeySecretRef:
      name: letsencrypt
    solvers:
    - http01:
        ingress:
          class: $INGRESS_CLASS
          podTemplate:
            spec:
              nodeSelector:
                "kubernetes.io/os": linux
EOF

```
## keycloak 배포
```s
####################### deploy keycloak ###################
# Add The keycloak repo
helm repo add codecentric https://codecentric.github.io/helm-charts

# deploy
helm install keycloak codecentric/keycloak \
                --namespace keycloak \
                --set ingress.enabled=true \
                --set ingress.annotations."kubernetes\.io/ingress\.class"=$INGRESS_CLASS \
                --set ingress.annotations."cert-manager\.io/cluster-issuer"=letsencrypt \
                --set ingress.annotations."nginx\.ingress\.kubernetes\.io/force-ssl-redirect"=\"true\" \
                --set ingress.rules[0].host=$DOMAIN \
                --set ingress.rules[0].paths[0].path="/" \
                --set ingress.rules[0].paths[0].pathType=Prefix \
                --set ingress.tls[0].hosts[0]=$DOMAIN \
                --set ingress.tls[0].secretName=tls-secret \
                --set extraEnv="
- name: KEYCLOAK_USER
  value: $KEYCLOAK_ADMIN
- name: KEYCLOAK_PASSWORD
  value: $KEYCLOAK_PASSWORD
- name: PROXY_ADDRESS_FORWARDING
  value: \"true\""

```

## 결과
```s
NAME: keycloak
LAST DEPLOYED: Tue Jan 25 01:26:39 2022
NAMESPACE: keycloak
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
***********************************************************************
*                                                                     *
*                Keycloak Helm Chart by codecentric AG                *
*                                                                     *
***********************************************************************

Keycloak was installed with an Ingress and an be reached at the following URL(s):

  - https://keycloak.koreacentral.cloudapp.azure.com/
```