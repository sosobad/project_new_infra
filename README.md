# AWS MSA 기반 인프라 생성 가이드

이 묶음은 이전 애플리케이션 ZIP을 수정한 것이 아닌, 별도로 작성한 AWS 인프라 Terraform 프로젝트입니다. 기존 terraform 폴더와 섞지 말고 별도 폴더에서 실행하세요. .tf.json은 Terraform이 공식 지원하는 JSON 설정 문법이며 .tf와 동일하게 자동 로드됩니다.

## 생성 범위
VPC 10.0.0.0/16, ap-northeast-2a/2c, public 2개, private EKS 2개, isolated DB 2개, IGW, AZ별 NAT Gateway 2개, EKS+관리형 노드 2대, EKS 기본 애드온/Pod Identity Agent, private RDS MySQL, TLS Redis OSS ElastiCache, Redis Secret, private S3, ECR 5개, Route53 zone 선택 생성 및 LB Alias 레코드.

실제 AWS apply 검증은 하지 않았습니다. 실행 환경에 Terraform이 없어 init/validate도 실행하지 못했으며 JSON 구문/리소스 참조 검사를 수행했습니다. AWS 계정의 quota, 가용 엔진/애드온 버전, IAM 권한을 plan/apply 과정에서 확인해야 합니다. 운영 인증을 받았다는 의미가 아닙니다.

## 1. 수정할 파일
`terraform.tfvars.json.example`을 `terraform.tfvars.json`으로 복사하고 아래를 변경합니다.

| 키 | 입력 값 |
|---|---|
| project | 새 리소스 접두사. 소문자/숫자/하이픈, 짧게 지정 |
| region | 기본 ap-northeast-2 |
| domain_name | 구매한 도메인 (예: wecnedu.com) |
| hosted_zone_id | Route53 → Hosted zones → 해당 도메인 → Hosted zone ID |
| admin_cidrs | kubectl 실행 PC의 현재 공인 IP/32, 예: 1.2.3.4/32 |
| admin_role_arn | 실제 사용/AssumeRole 가능한 IAM 관리자 Role ARN. STS assumed-role ARN이나 사용자 ARN이 아님 |
| frontend_origin | https://www.실제도메인 |
| kubernetes_version | 기본 1.35. 서울 리전 지원 버전 확인 |
| multi_az | true: RDS Multi-AZ + Redis 2대. false: 단일 DB + Redis 1대 |
| lb_dns_name / lb_zone_id | 첫 실행에는 빈 문자열. LB 설치 후 입력 |

AWS 계정 ID는 자동 조회하므로 ECR 주소를 하드코딩할 필요 없습니다.
이미 구매한 도메인의 Hosted Zone이 있으면 ID를 입력하세요. 빈 문자열이면 **새 Hosted Zone만** 생성하며 도메인 구매/등록은 수행하지 않습니다. 새 zone을 생성했다면 Route53 Registered domains의 네임서버를 output name_servers로 맞춰야 합니다.

## 2. Windows PowerShell 실행
AWS CLI, Terraform >=1.6, kubectl 설치 및 AWS 관리자 Role 로그인 필요.

```powershell
cd C:\Users\soldesk\Desktop\aws-infra
Copy-Item terraform.tfvars.json.example terraform.tfvars.json
notepad terraform.tfvars.json
aws sts get-caller-identity
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out infra.tfplan
terraform apply infra.tfplan
terraform output
aws eks update-kubeconfig --region ap-northeast-2 --name msa-platform
kubectl get nodes
```

project를 바꿨으면 update-kubeconfig의 name도 변경하세요. AWS CLI 프로필은 admin_role_arn의 역할을 사용하도록 설정해야 합니다. Terraform 생성 실행자는 EKS 접속권한이 자동 부여되지 않습니다. 지정한 admin_role_arn에만 관리자 access entry를 생성합니다.

Node Group max_size=5는 자동확장 설정 자체가 아닙니다. Cluster Autoscaler/Karpenter는 별도 설치가 필요합니다.

## 3. 로드밸런서와 Route53
EKS 생성만으로 LB, HTTPS, Ingress controller가 설치되지 않습니다. 이 묶음에는 ArgoCD/Grafana/Prometheus/애플리케이션 설치도 포함되지 않습니다.

신규 구성은 AWS Load Balancer Controller의 ALB Ingress를 기준으로 후속 구성하세요. ALB가 Service로 직접 라우팅하는 구조이며 ALB 뒤에 ingress-nginx가 자동 설치되는 구조가 아닙니다. 기존 ingress-nginx 방식 유지 여부는 별도로 판단해야 합니다.

AWS Load Balancer Controller에 별도 IAM Role/Pod Identity, Helm 설치가 필요합니다. HTTPS는 ACM 인증서 DNS 검증 및 Ingress certificate-arn 설정이 필요합니다. LB 생성 후 다음으로 조회:

```powershell
aws elbv2 describe-load-balancers --region ap-northeast-2 --query 'LoadBalancers[].{Name:LoadBalancerName,DNS:DNSName,Zone:CanonicalHostedZoneId}' --output table
```

사용할 LB의 DNS를 lb_dns_name, CanonicalHostedZoneId를 lb_zone_id에 입력하고 terraform plan/apply를 다시 실행합니다. 다섯 호스트가 모두 같은 LB를 가리키므로 각각의 host routing Ingress가 있어야 합니다. 관리 도구는 외부에 열기 전에 인증/접근제한을 별도로 구성하세요.

## 4. 애플리케이션에 연결

| terraform output | 기존 프로젝트 적용 위치(이전 대화에서 제시된 경로) |
|---|---|
| rds_endpoint | k8s/base/config.yaml: 서비스별 jdbc:mysql://endpoint:3306/member_db 또는 product_db/order_db |
| redis_endpoint | k8s/base/config.yaml: REDIS_HOST |
| redis_secret_arn | Secrets Manager에서 앱 전용 역할로 읽고 External Secrets 또는 CSI로 주입 |
| s3_bucket | k8s/base/config.yaml: S3_BUCKET |
| ecr_urls | k8s/overlays/prod/kustomization.yaml: images의 newName 및 newTag |
| 도메인 | k8s/base/ingress.yaml의 hosts 및 frontend API URL |

기존 ZIP의 실제 파일은 이번 작업에서 읽지 않았으므로 위 경로는 이전 대화의 경로입니다. 실제 키/파일 내용에 맞춰 적용하세요.

Spring Redis는 host만 바꾸면 안 됩니다:
```yaml
spring:
  data:
    redis:
      host: ${REDIS_HOST}
      port: 6379
      password: ${REDIS_PASSWORD}
      ssl:
        enabled: true
```
REDIS_PASSWORD는 Secret에서 주입하세요. DB TLS는 Connector/J의 sslMode=VERIFY_IDENTITY 및 AWS RDS CA truststore 설정을 사용하세요.

RDS 생성은 서비스 DB와 DB 사용자를 자동 생성하지 않습니다. VPC 내부 작업용 Pod/호스트에서 master secret으로 접속해 member_db/product_db/order_db 및 서비스별 runtime/migration 계정을 생성해야 합니다. 운영 앱에 master 계정을 넣지 마세요. Flyway migration 계정에는 필요한 DDL 권한, runtime 계정에는 해당 스키마의 SELECT/INSERT/UPDATE/DELETE만 부여하세요.

S3 권한은 production namespace의 product-service ServiceAccount와 연결했습니다. 애플리케이션 Pod에 serviceAccountName: product-service를 지정하고 이 ServiceAccount를 별도 생성해야 합니다. SDK는 Pod Identity를 지원하는 최신 기본 credential chain을 사용하세요. 업로드 object key는 products/로 시작해야 합니다. private S3 URL은 그대로 공개 조회할 수 없으므로 presigned GET 또는 CloudFront OAC 구성이 필요합니다.

RDS/Redis SG는 현재 기본 관리형 노드의 EKS cluster security group을 출발지로 허용합니다. 별도 node SG/Pod SG를 적용하면 04-rds-redis.tf.json의 referenced_security_group_id를 실제 SG로 변경해야 합니다. 현재는 클러스터 내부 모든 기본 노드가 접근 가능하며 서비스별 최소권한 분리는 후속 NetworkPolicy/Pod SG 구성 영역입니다.

## 5. 파일 역할
01: provider/변수 / 02: 네트워크 / 03: EKS/IAM / 04: RDS/Redis/Secret / 05: S3/ECR/상품 Pod Identity / 06: DNS / 07: 출력.

## 6. 비용과 상태 관리
apply를 하면 EKS, EC2, NAT 2개, RDS, Redis 등의 요금이 발생합니다. 이번 작업에서는 AWS 리소스를 생성하지 않았습니다.
기본 state는 로컬이며 Redis 비밀번호가 state에 포함됩니다. sensitive 표시로 state의 평문 저장을 막을 수 없습니다. .tfstate와 tfplan을 Git에 올리지 마세요. 팀 운영에는 별도 bootstrap으로 암호화된 비공개 S3 backend + use_lockfile을 구성하고 접근을 제한해야 합니다. 이미지용 S3 버킷을 state backend로 재사용하지 마세요. .terraform.lock.hcl은 init 후 Git에 커밋하여 provider 버전을 고정하세요.
RDS deletion_protection=true, S3/ECR force 삭제 비활성화로 데이터 삭제를 제한합니다. 제거하려면 백업/내용 정리와 삭제 보호 해제가 필요합니다. final snapshot 이름이 이미 존재하면 새 이름으로 수정해야 합니다.
