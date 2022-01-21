## ubuntu 20.04기준

### 사용할 도메인 정보

domain=keycloak.koreacentral.cloudapp.azure.com

# podman 설치
. /etc/os-release
echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/ /" | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
curl -L "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/Release.key" | sudo apt-key add -
sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get -y install podman

# ssl termination 사용을 위해 nginx proxy사용

## nginx 설치
sudo apt update

sudo apt install nginx

echo "upstream keycloak {
    # sticky cookie srv_id expires=1h domain=$domain; ## only nginx plus
    server 127.0.0.1:8080;
}
server {
    server_name $domain;
    # root /var/www/html;
    location / {
        proxy_pass http://keycloak;
        # proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_ssl_session_reuse on;
        proxy_send_timeout 300s;
    }
}" | sudo tee /etc/nginx/conf.d/$domain.conf > /dev/null

## certbot 설치
sudo snap install core; sudo snap refresh core

sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot
## Lets encrypt 인증서는 일주일에 5개 까지밖에 만들지 못하니 배포 시 주의
sudo certbot --nginx -d $domain


# keycloak podman에 설치
podman run -dt \
            -e KEYCLOAK_USER=admin \
            -e KEYCLOAK_PASSWORD=admin \
            -e PROXY_ADDRESS_FORWARDING=true \
            --name keycloak quay.io/keycloak/keycloak:16.1.0

