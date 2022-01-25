. variables.sh
# Create a namespace for deployment
kubectl create ns keycloak

############## ingress #########################

# Add the ingress-nginx repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

# Use Helm to deploy an NGINX ingress controller
## 사용자 지정 도메인 사용 시 --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-dns-label-name"="$DNS_LABEL" 줄 제거
helm install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace keycloak \
    --set controller.replicaCount=1 \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-dns-label-name"="$DNS_LABEL" \
    --set controller.ingressClass=$INGRESS_CLASS


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


read -p "issuer 등록용 메일 주소 입력:" EMAIL_ADDR
out=""
while [ "$out" != 'clusterissuer.cert-manager.io/letsencrypt configured' ]
do
sleep 1
#issuer 생성
out=$(cat <<EOF | kubectl apply -f - 
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
)
done
echo 'clusterissuer.cert-manager.io/letsencrypt created'
####################### deploy keycloak ###################
# Add The keycloak repo
helm repo add codecentric https://codecentric.github.io/helm-charts

# Deploy
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
