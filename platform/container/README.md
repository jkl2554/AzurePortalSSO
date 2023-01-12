# Container 배포  
## [deploy_container.sh](./deploy_container.sh)  
- Nginx 및 Certbot host machine에 설치  
- podman에 keycloak container만 설정  

```s
## ubuntu 20.04기준

### 사용할 도메인 정보

domain=keycloak.koreacentral.cloudapp.azure.com
```
## podman 설치
```s
# podman 설치
. /etc/os-release
echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/ /" | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
curl -L "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/Release.key" | sudo apt-key add -
sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get -y install podman
```

## nginx 설치
ssl termination 사용을 위해 nginx proxy사용
```s
## nginx 설치
sudo apt update

sudo apt install nginx
```
## nginx config 설정
80 -> 8080 포트포워딩 설정
```s
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
```
## Certbot을 이용해 인증서 발급
```s
## certbot 설치
sudo snap install core; sudo snap refresh core

sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot
## Lets encrypt 인증서는 일주일에 5개 까지밖에 만들지 못하니 배포 시 주의
sudo certbot --nginx -d $domain
```
## keycloak conatainer 실행
```s
# keycloak podman에서 실행
podman run -dt \
            -e KEYCLOAK_USER=admin \
            -e KEYCLOAK_PASSWORD=admin \
            -e PROXY_ADDRESS_FORWARDING=true \
            --name keycloak quay.io/keycloak/keycloak:16.1.0
```

## [deploy_pod.sh](./deploy_pod.sh)  
- Pod로 묶어서 배포  
- iptables 에서 80->8080, 443->8443으로 nat  
- container배포작업은 모두 rootless  

```s
## ubuntu 20.04기준

### 사용할 도메인 정보

domain=keycloak.koreacentral.cloudapp.azure.com
```
## podman 설치
```s
#podman 설치
. /etc/os-release
echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/ /" | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
curl -L "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/Release.key" | sudo apt-key add -
sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get -y install podman
```
## 방화벽 설정
방화벽 설정을 통해 80,443 -> 8080,8443포트에 각각 포트포워딩
```s
## IP tables를 이용해 80 443 포트 8080 8443에 각각 매핑
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
sudo iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8443
sudo iptables -t nat -L PREROUTING

# Chain PREROUTING (policy ACCEPT)
# target     prot opt source               destination
# CNI-HOSTPORT-DNAT  all  --  anywhere             anywhere             ADDRTYPE match dst-type LOCAL
# REDIRECT   tcp  --  anywhere             anywhere             tcp dpt:http redir ports 8080
# REDIRECT   tcp  --  anywhere             anywhere             tcp dpt:https redir ports 8443

sudo iptables-save
```
## Container 배포
```s
## nginx-certbot 컨테이너 배포

mkdir user_conf.d nginx_secrets

echo "upstream keycloak {
    # sticky cookie srv_id expires=1h domain=$domain; ## only nginx plus
    server 127.0.0.1:8080;
}

server {
    # Listen to port 443 on both IPv4 and IPv6.
    listen 443 ssl default_server reuseport;
    listen [::]:443 ssl default_server reuseport;

    # Domain names this server should respond to.
    server_name $domain;
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
    # Load the certificate files.
    ssl_certificate         /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key     /etc/letsencrypt/live/$domain/privkey.pem;
    ssl_trusted_certificate /etc/letsencrypt/live/$domain/chain.pem;

    # Load the Diffie-Hellman parameter.
    ssl_dhparam /etc/letsencrypt/dhparams/dhparam.pem;
}" > $(pwd)/user_conf.d/$domain.conf


## Lets encrypt 인증서는 일주일에 5개 까지밖에 만들지 못하니 배포 주의
podman run -dt -p 8080:80 -p 8443:443 --pod new:keycloak-pod \
           --env CERTBOT_EMAIL=<Your Email> \
           -v $(pwd)/nginx_secrets:/etc/letsencrypt \
           -v $(pwd)/user_conf.d:/etc/nginx/user_conf.d:ro \
           --name nginx-certbot jonasal/nginx-certbot:latest
```
## keycloak 배포
```s
# keycloak podman 배포
podman run -dt --pod keycloak-pod \
            -e KEYCLOAK_USER=admin \
            -e KEYCLOAK_PASSWORD=admin \
            -e PROXY_ADDRESS_FORWARDING=true \
            --name keycloak quay.io/keycloak/keycloak:16.1.0

podman logs -f nginx-certbot
```
## System 데몬 등록
```s
mkdir -p ~/.config/systemd/user/
podman generate systemd keycloak -f ~/.config/systemd/user/keycloak  ## keycloak.service
podman generate systemd nginx-certbot -f ~/.config/systemd/user/nginx-certbot  ## nginx-certbot.service
## 서비스
systemctl --user enable keycloak
systemctl --user enable nginx-certbot
```
## 삭제
```s
podman pod rm -f keycloak-pod ## Pod 삭제 명령어.
```