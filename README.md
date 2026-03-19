# cf_test
 KT Cloud 인프라 과정(2회차) 심화프로젝트 과정 중 cloudflare tunnel 연습

간단히 테라폼 및 앤서블로 실행 시키는 코드

현재 로컬 테스트를 기준으로 작성되어 있음

앤서블 코드로 각각의 vm 에 동시에 접속하여 수행 시킴

도메인으로 접속 하여 정상 작동 확인, failover로 aws 로 이동 확인(시간이 좀 걸림)



    cd terraform && terraform apply -auto-approve
    cd ../ansible && ansible-playbook -i inventory.ini deploy-tunnel.yml