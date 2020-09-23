vpc-ecs-n-ecr-environment-remote-state role
===========================================

Create vpc-ecs-n-ecr-environment terraform remote state S3 bucket
Create vpc-ecs-n-ecr-environment-remote-state terraform remote state dynamoDB lock table

Example Playbook use
--------------------
    - hosts: servers
      roles:
        - role: vpc-ecs-n-ecr-environment-remote-state

