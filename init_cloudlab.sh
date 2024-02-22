#!/usr/bin/env bash

# Set on every new instantiation
### TO BE FILLED: Please provide all cluster IPs
# Node w/ first IP (i.e., "manager") must run script before the rest of the nodes
# (instantiates a memcached to setup RDMA connections)
ORDERED_HOST_NAMES=(
	"apt152.apt.emulab.net"
	"apt137.apt.emulab.net"
	"apt162.apt.emulab.net"
	"apt161.apt.emulab.net"
	"apt140.apt.emulab.net"
)

# install parallel
sudo apt update
sudo apt install parallel -y

mkdir ~/.parallel
touch ~/.parallel/will-cite

# Include cloudlab_ssh_config in ssh
# assumes you have created a key w/ ssh-keygen (here named id_rsa_cloudlab)
# and already registered its public key on cloudlab

# set once
CLOUDLAB_USERNAME="siavash"
SSH_CONFIG="${HOME}/.ssh/config"
CLOUDLAB_SSHKEY_FILE="${HOME}/.ssh/id_rsa_cloudlab"

SSH_PREFIX="n"
CONFIG_NAME="cloudlab_ssh_config"
SCRIPT_TO_COPY_N_RUN="init.sh"

# Create file
echo "# cloudlab config" >${CONFIG_NAME}
echo " " >>${CONFIG_NAME}
for i in "${!ORDERED_HOST_NAMES[@]}"; do
	{
		echo "Host ${SSH_PREFIX}$((i + 1))"
		echo "    User ${CLOUDLAB_USERNAME}"
		echo "    IdentityFile ${CLOUDLAB_SSHKEY_FILE}"
		echo "    HostName ${ORDERED_HOST_NAMES[i]}"
		echo " "
	} >>${CONFIG_NAME}
done

cp ${CONFIG_NAME} ~/.ssh/

# Include in ssh_config if it does not exist
if cat ~/.ssh/config | grep "Include ${CONFIG_NAME}"; then
	echo "${CONFIG_NAME} is already included in your ${SSH_CONFIG}"
else
	echo "Including ${CONFIG_NAME} in your ${SSH_CONFIG}"

	cp ${SSH_CONFIG} ${SSH_CONFIG}_backup # take a backup of ssh config
	echo "Include ${CONFIG_NAME}" >${SSH_CONFIG}
	echo " " >>${SSH_CONFIG}
	cat ${SSH_CONFIG}_backup >>${SSH_CONFIG}
fi

##insert to known_hosts
for i in "${!ORDERED_HOST_NAMES[@]}"; do
	ssh-keyscan -H ${ORDERED_HOST_NAMES[i]} >>~/.ssh/known_hosts
done

SSH_REMOTE_SSHKEY="/users/${CLOUDLAB_USERNAME}/.ssh/id_rsa"
MACHINE_LIST_IDS=$(seq -s " " 1 ${#ORDERED_HOST_NAMES[@]})

# copy id_rsa_cloudlab to internal nodes (to allow access/scp with each other)
# and init to setup their initial environment
echo "Copying ssh_key and ${SCRIPT_TO_COPY_N_RUN} in cloudlab nodes: ${MACHINE_LIST_IDS}"
parallel scp ${CLOUDLAB_SSHKEY_FILE} ${SSH_PREFIX}{}:${SSH_REMOTE_SSHKEY} ::: ${MACHINE_LIST_IDS}
parallel scp ./${SCRIPT_TO_COPY_N_RUN} ${SSH_PREFIX}{}:~/${SCRIPT_TO_COPY_N_RUN} ::: ${MACHINE_LIST_IDS}

# run script
echo "Running ${SCRIPT_TO_COPY_N_RUN} in cloudlab nodes: ${MACHINE_LIST_IDS}"
parallel ssh ${SSH_PREFIX}{} './'"${SCRIPT_TO_COPY_N_RUN}"'' ::: ${MACHINE_LIST_IDS}
echo "Init done!"
