# Container 배포  
## [deploy_container.sh](./deploy_container.sh)  
- Nginx 및 Certbot host machine에 설치  
- podman에 keycloak container만 설정  

## [deploy_pod.sh](./deploy_pod.sh)  
- Pod로 묶어서 배포  
- iptables 에서 80->8080, 443->8443으로 nat  
- container배포작업은 모두 rootless  