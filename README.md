# AzurePortalSSO
## 리소스 배포
1. 가상머신 배포
- 가상머신 사이즈는 상관 없음
2. IP에 DNS Lable등록(선택사항, 도메인 있을 경우 필요없음)
- DNS Lable 등록 해 도메인 사용
## 애플리케이션 배포
## [keycloak 설정](./keycloak/)
## Azure Portal 설정
### Direct Federation 설정
Azure Active Directory - External Identities - All Identity providers  
\+ New SAML/WS-Fed Idp
- Identity provider protocol: `SAML`
- Domain name of federating IdP: `<Your domain>`
- Select a method of populating metadata: `Parse metadata file`
- Metadata file: `idp-metadata.xml` *keycloak 설정에서 받은 Installation file  

Parse 후 Save  

*참고 문서  
https://docs.microsoft.com/ko-kr/azure/active-directory/external-identities/direct-federation

### 테스트 유저 생성
Azure Active Directory - Users
\+ New Guest User

- Email Address: `test@<your domain>`

## Federation 동작 테스트

- https://portal.azure.com/\<tenant id\>로 접속  
- `test@<your domain>`으로 로그인 시도  
- Keycloak 로그인창으로 리다이렉션 및 로그인
- keycloak 로그인 성공 후 게스트 초대 수락
- 정상적으로 로그인 확인