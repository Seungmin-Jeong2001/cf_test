# cf_test
 KT Cloud 인프라 과정(2회차) 심화프로젝트 과정 중 cloudflare tunnel 연습

간단히 테라폼 코드로 aws 인스턴스 생성 후

생성된 인스턴스에 앤서블로 k3s 설치 및 클라우드 플레어 터널 설정 적용되는 것을 확인 하는 코드


1.  **Terraform Apply:**
    ```bash
    cd terraform
    terraform init
    terraform apply -auto-approve
    ```
    *   완료되면 `ansible/inventory.ini` 파일이 자동으로 생성됩니다.

2.  **Ansible 실행:**
    ```bash
    cd ../ansible
    # terraform에서 나온 토큰을 extra-vars로 전달
    ansible-playbook -i inventory.ini deploy-tunnel.yml -e "tunnel_token=아까_발급받은_토큰값"
    ```

3.  **검증:**
    ```bash
    # AWS 서버에 접속하여 파드가 잘 떴는지 확인
    ssh ubuntu@[AWS_PUBLIC_IP]
    sudo kubectl get pods
  다음 단계
   1. terraform 디렉토리로 이동하여 terraform apply를 실행해 인벤토리 파일을 업데이트하세요. (이미 적용된 상태라면 파일만 갱신됩니다.)
   1     cd terraform && terraform apply -auto-approve
   2. 다시 Ansible 플레이북을 실행하세요.


   1     cd ../ansible && ansible-playbook -i inventory.ini deploy-tunnel.yml