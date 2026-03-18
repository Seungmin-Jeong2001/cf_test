# GitHub Actions에서 Cloudflare API 토큰 및 ID 사용 가이드

이 가이드는 `terraform.tfvars`에 직접 기록된 민감한 정보(API Token, Account ID, Zone ID)를 GitHub Actions의 **Secrets** 기능을 사용하여 안전하게 CI/CD 환경에 연동하는 방법을 설명합니다.

---

## 1. GitHub Repository에 Secrets 등록하기

먼저, 깃허브 저장소 설정에서 보안 변수를 등록해야 합니다.

1.  GitHub 저장소의 **Settings** 탭으로 이동합니다.
2.  왼쪽 메뉴에서 **Secrets and variables** > **Actions**를 클릭합니다.
3.  **New repository secret** 버튼을 눌러 아래 변수들을 추가합니다:

| Secret 이름 | 설명 |
| :--- | :--- |
| `CF_API_TOKEN` | Cloudflare API 토큰 값 |
| `CF_ACCOUNT_ID` | Cloudflare 계정 ID |
| `CF_ZONE_ID` | Cloudflare Zone(도메인) ID |

---

## 2. GitHub Actions Workflow 파일 설정 (.yml)

Terraform은 `TF_VAR_변수명` 형태의 환경 변수를 자동으로 인식합니다. 워크플로우 파일(`main.yml` 등)에서 다음과 같이 환경 변수를 설정하세요.

```yaml
jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Terraform Init
        run: terraform init
        working-directory: ./terraform

      - name: Terraform Plan
        run: terraform plan
        working-directory: ./terraform
        env:
          # GitHub Secrets를 Terraform 변수로 매핑
          TF_VAR_cf_api_token: ${{ secrets.CF_API_TOKEN }}
          TF_VAR_cf_account_id: ${{ secrets.CF_ACCOUNT_ID }}
          TF_VAR_cf_zone_id: ${{ secrets.CF_ZONE_ID }}
          # AWS 인증 정보도 필요하다면 추가 (보통 AWS_ACCESS_KEY_ID 등 사용)
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

---

## 3. 로컬 환경 보안 강화 (`.gitignore`)

현재 `terraform.tfvars`에 실명 키값이 포함되어 있다면, 실수로 GitHub에 커밋되지 않도록 `.gitignore` 파일을 수정하는 것이 권장됩니다.

1.  **`.gitignore` 파일 수정:**
    ```bash
    # terraform.tfvars 파일이 커밋되지 않도록 추가
    terraform/*.tfvars
    terraform/*.tfstate*
    ```

2.  **`terraform.tfvars.example` 생성 (선택사항):**
    팀원들이 어떤 변수가 필요한지 알 수 있도록 값은 비워두고 형식만 갖춘 예시 파일을 만듭니다.
    ```hcl
    # terraform/terraform.tfvars.example
    cf_api_token   = ""
    cf_account_id  = ""
    cf_zone_id     = ""
    ```

---

## 4. 요약: Terraform 변수 우선순위

Terraform은 다음 순서대로 변수 값을 읽습니다:
1.  명령줄 인수 (`-var='...'`)
2.  **환경 변수 (`TF_VAR_...`)**  <-- CI/CD에서 주로 사용하는 방식
3.  `terraform.tfvars` 파일
4.  변수 선언부의 `default` 값

따라서 GitHub Actions에서 `TF_VAR_` 환경 변수를 설정해주면, 로컬의 `tfvars` 파일 없이도 안전하게 배포를 자동화할 수 있습니다.
