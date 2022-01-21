## ubuntu 20.04기준

### 사용할 도메인 정보

domain=keycloak.koreacentral.cloudapp.azure.com


## pod에 배포

#podman 설치
. /etc/os-release
echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/ /" | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
curl -L "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/Release.key" | sudo apt-key add -
sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get -y install podman



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

## container 배포작업

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
           --env CERTBOT_EMAIL=jkl2554@cloocus.com \
           -v $(pwd)/nginx_secrets:/etc/letsencrypt \
           -v $(pwd)/user_conf.d:/etc/nginx/user_conf.d:ro \
           --name nginx-certbot jonasal/nginx-certbot:latest

# keycloak podman에 설치
podman run -dt --pod keycloak-pod \
            -e KEYCLOAK_USER=admin \
            -e KEYCLOAK_PASSWORD=admin \
            -e PROXY_ADDRESS_FORWARDING=true \
            --name keycloak quay.io/keycloak/keycloak:16.1.0

podman logs -f nginx-certbot


## podman generate systemd keycloak -f keycloak  ## keycloak.service
## podman generate systemd nginx-certbot -f nginx-certbot  ## nginx-certbot.service

## /etc/systemd/system/<서비스 명>.service -> Podman 서비스 생성(root)  systemctl enable <서비스 명>
## ~/.config/systemd/user/<서비스 명>.service -> Podman 서비스 생성(user) systemctl --user enable <서비스 명>

## podman pod rm -f keycloak-pod ## Pod 삭제 명령어.