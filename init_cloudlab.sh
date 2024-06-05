#!/usr/bin/env bash

HOSTS_FILE="./hosts"
readarray -t ORDERED_HOST_NAMES <"${HOSTS_FILE}"

if command -v parallel &>/dev/null; then
  # install parallel
  sudo apt update
  sudo apt install parallel -y

fi

mkdir -p ~/.parallel
touch ~/.parallel/will-cite

CLOUDLAB_USERNAME="siavash"
SSH_CONFIG="${HOME}/.ssh/config"
CLOUDLAB_SSHKEY_FILE="${HOME}/.ssh/id_rsa_cloudlab"

SSH_PREFIX="n"
CONFIG_NAME="cloudlab_ssh_config"
SCRIPT_TO_COPY_N_RUN="init.sh"

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

cp ${CONFIG_NAME} "$HOME/.ssh/"

# Include in ssh_config if it does not exist
if cat "$HOME"/.ssh/config"" | grep "Include ${CONFIG_NAME}"; then
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
