#!/bin/bash

set -e


# Gather data
host="$(\cat ./inventory)"
localhost="$(hostname)"
ssh_key_path="$HOME/.ssh/id_ed25519_ansible@$localhost"

echo -e "--| Setup ansible access in $host"


# Setup ansible user
read -r -p "--| Name of the default user in the data server: " default_usr
read -rs -p "--| Enter the password for the default user:" DEFAULT_USR_PWD
export DEFAULT_USR_PWD
echo ""
read -rs -p "--| Enter a password for the ansible user to be created: " ansible_usr_pwd
echo ""
ansible_usr_hash=$(echo "$ansible_usr_pwd" | mkpasswd --method=SHA-256 --stdin)

echo -e "--| Setting up ansible user..."

ansible "$host" -u "$default_usr" -b \
    -e ansible_become_pass='{{ lookup( "env", "DEFAULT_USR_PWD") }}' \
    -m user -a "name=ansible password=$ansible_usr_hash"

ansible "$host" -u "$default_usr" -b \
    -e ansible_become_pass='{{ lookup( "env", "DEFAULT_USR_PWD") }}' \
    -m copy -a 'dest=/etc/sudoers.d/ansible content="ansible ALL=(ALL) NOPASSWD: ALL" mode=0440 validate="visudo -cf %s"'


# Setup ssh access
echo -e "--| Setting up ssh access..."

if ! [[ -f "$ssh_key_path" ]]; then
    echo -e "--| Generating ssh key for ansible user..."

    read -rs -p "--| Enter the password for the $ssh_key_path key to be created: " ssh_key_pwd

    ssh-keygen -t ed25519 -C "ansible@$localhost" -f "$HOME/.ssh/id_ed25519_ansible@$localhost" -N "$ssh_key_pwd"
else
    read -rs -p "--| Enter $ssh_key_path password: " ssh_key_pwd
fi

eval "$(ssh-agent -s)" && ssh-add "$ssh_key_path"

ssh-copy-id -i "$ssh_key_path.pub" -o PasswordAuthentication=yes -o PubkeyAuthentication=no "ansible@$host"
