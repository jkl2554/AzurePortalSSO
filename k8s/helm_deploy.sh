# Create a namespace for your ingress resources
kubectl create ns keycloak

$INGRESS_CLASS="azure/application-gateway"


############## ingress #########################
$INGRESS_CLASS="keycloak-ingress"
# Add the ingress-nginx repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

# Use Helm to deploy an NGINX ingress controller
helm install nginx-ingress ingress-nginx/ingress-nginx \
    --namespace keycloak \
    --set controller.replicaCount=1 \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-dns-label-name"="hyugo-sso" \
    --set controller.ingressClass=$INGRESS_CLASS
# Label the ingress-basic namespace to disable resource validation
kubectl label namespace keycloak cert-manager.io/disable-validation=true

################# cert manager #####################
# Add the Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io

# Update your local Helm chart repository cache
helm repo update

# Install the cert-manager Helm chart
helm install cert-manager jetstack/cert-manager --namespace keycloak --version v0.16.1 --set installCRDs=true --set nodeSelector."kubernetes\.io/os"=linux --set webhook.nodeSelector."kubernetes\.io/os"=linux --set cainjector.nodeSelector."kubernetes\.io/os"=linux

#issuer 생성
kubectl apply -f cluster-issuer.yaml -n keycloak
####################### deploy key cloak
#Add The keycloak repo
helm repo add codecentric https://codecentric.github.io/helm-charts

# 첫 수정 필요 시
# helm show values codecentric/keycloak > keycloak_values.yaml

helm install keycloak -f keycloak_values.yaml codecentric/keycloak --namespace keycloak --set ingress.annotations."kubernetes\.io/ingress\.class"=$INGRESS_CLASS --set ingress.annotations."appgw\.ingress\.kubernetes\.io/ssl-redirect"=true


