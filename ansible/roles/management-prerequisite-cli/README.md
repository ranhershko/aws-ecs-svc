management-prerequisite-cli role
================================

Prepare management server:
1) Install needed cli\'s: terraform, vault, jq, aws
2) Create user home bin and update .bashrc

Example Playbook use
--------------------

    - hosts: localhost
      roles:
        - role: management-prerequisite-cli

