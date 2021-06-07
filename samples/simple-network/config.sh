#!/bin/bash

# Copyright 2019 IBM Corp.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#   http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script is only the script for running ipfs on Docker containers on all simple network scenarios (p2p, p2s, p2sp and server)
# This script will ensure that
# 1) Each containers (whether servers or peers) have different peer id
# This will be significant because we use different id to identify each
# peers or servers, and connect them to one network.
# 2) Each containers can keep running in backend
# The function `ipfs init` will disrupt containers running in backend if
# executed twice or above. By implementing config check, will keep containers
# running healthily in backend even on restart.

# Set environment variable
export PATH=${PWD}:$PATH
export IPFS_CONFIG=${IPFS_PATH}/config
export SWARM_KEY_FILE=${IPFS_PATH}/swarm.key
export WEB_UI_DIR=${IPFS_PATH}/${WEBUI_CID}

# Print the help message.
function printHelper() {
	echo "Usage: "
	echo "  config.sh init - initialize IPFS config if not already initialized."
	echo "  config.sh daemon - run IPFS daemon process for target network."
	echo "Flags: "
	echo "  -p <profile> - the IPFS profile for initialization (defaults to default-networking)."
	echo "  -r <routing> - routing option for IPFS node (defaults to default)."
	echo "	-m <migrate> - option for auto repo migration (defaults to false)."
}

# Check whether ipfs configuration file already exists.
function init() {
	if [ ! -e "$IPFS_CONFIG" ]; then
		echo "---- No IPFS configuration file found, ${MESSAGE}... ----"
		ipfs init --profile=$PROFILE
		if [ "$PROFILE" == "$SERVER_NS" ]; then
			configAddresses
			addWebUI
			configCors
		fi
	fi
}

# Configure the api and gateway endpoint
function configAddresses() {
	# Grab current api address
	CURRENT_API_ADDR=$(ipfs config Addresses.API | cut -d '/' -f3)
	# Grab current gateway address
	CURRENT_GATEWAY_ADDR=$(ipfs config Addresses.Gateway | cut -d '/' -f3)
	# Compare addresses and change to global api and gateway
	if [ "$CURRENT_API_ADDR" != "$GLOBAL_ADDR" ]; then
		echo "---- Configuring the api endpoint, defaults for the server. ----"
		set -x
		ipfs config Addresses.API $INTERNET_PRO/$GLOBAL_ADDR/$COMM_PRO/$API
		set +x
	fi
	if [ "$CURRENT_GATEWAY_ADDR" != "$GLOBAL_ADDR" ]; then
		echo "---- Configuring the gateway endpoint, defaults for the server. ----"
		set -x
		ipfs config Addresses.Gateway $INTERNET_PRO/$GLOBAL_ADDR/$COMM_PRO/$GATEWAY
		set +x
	fi
}

# Add Web UI
function addWebUI() {
	echo "---- Adding IPFS Web UI to private host. ----"
	set -x
	ipfs add -r $WEB_UI_DIR
	set +x
}

# Config CORS 
function configCors() {
	echo "---- Configuring CORS for the private host. ----"
	set -x
	# Grab public ip address of this machine
	PUBLIC_IP_ADDRESS=$(timeout 2 curl ifconfig.co)
	if [ "$?" -ne 0 ]; then
		echo "requesting address timed out, exit."
		exit 1
	fi
	set -e
	ipfs config --json API.HTTPHeaders.Access-Control-Allow-Origin "[\"http://$PUBLIC_IP_ADDRESS:$API\", \"https://$PUBLIC_IP_ADDRESS:$GATEWAY\"]"
	ipfs config --json API.HTTPHeaders.Access-Control-Allow-Methods '["PUT", "GET", "POST"]'
	set +x
}

# Run IPFS daemon process.
function daemon() {
	if [ ! -e "$SWARM_KEY_FILE" ]; then
		echo "---- Swarm key file not found, ${MESSAGE} a default network. ----"
	else
		echo "---- ${MESSAGE} a private network with a swarm key file. ----"
		set -x
		LIBP2P_FORCE_PNET=$PNET
		set +x
	fi
	ipfs daemon --routing=$ROUTING --migrate=$MIGRATE
}

# Set private network
PNET=1
# Set config profile
PROFILE=default-networking
# Set routing option
ROUTING=default
# Set repo migration
MIGRATE=false
# Set api port
API=5001
# Set gateway port
GATEWAY=8080
# Set global address
GLOBAL_ADDR=0.0.0.0
# Set communication protocol
COMM_PRO=tcp
# Set internet protocol
INTERNET_PRO=/ip4
# Set server name space
SERVER_NS=server
# Set private Web UI cid
WEBUI_CID=QmXc9raDM1M5G5fpBnVyQ71vR4gbnskwnB9iMEzBuLgvoZ

# The arg of the command
COMMAND=$1
shift

# Options for running command
while getopts "h?p:r:m" opt; do
	case "$opt" in
	h | \?)
		printHelper
		exit 0
		;;
	p)
		PROFILE=$OPTARG
		;;
	r)
		ROUTING=$OPTARG
		;;
	m)
		MIGRATE=true
		;;
	esac
done

# Command interface for message
if [ "$COMMAND" == "init" ]; then
	MESSAGE="Initializing"
elif [ "$COMMAND" == "daemon" ]; then
	MESSAGE="Running"
else
	printHelper
	exit 1
fi

# Command interface for execution
if [ "${COMMAND}" == "init" ]; then
	init
elif [ "${COMMAND}" == "daemon" ]; then
	daemon
else
	printHelper
	exit 1
fi
