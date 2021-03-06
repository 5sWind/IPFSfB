# A script for running the private network, each of peer-to-peer, peer-to-server, peer to peer and to server and server-only

# Set environment variable
export PATH=${PWD}/bin:${PWD}:$PATH
export BUILD_PATH=${PWD}/build

# Print the help message.
function printHelper() {
	echo "Usage: "
	echo "  pnet.sh <command> <subcommand>"
	echo "      <command> - one of 'up', 'down', 'restart' or 'generate'."
	echo "          - 'up' - start and up the network with docker-compose up."
	echo "          - 'down' - stop and clear the network with docker-compose down."
	echo "          - 'restart' - restart the network."
	echo "          - 'generate' - generate swarm key file."
	echo "      <subcommand> - network type, <subcommand=p2p|p2s|p2sp|so>."
	echo "Flags: "
	echo "  -n <network> - print all available network."
	echo "  -i <toolimagetag> - tag for the private network launch tool (defaults to latest)."
	echo "  -f <docker-compose-file> - docker-compose file to be selected (defaults to docker-compose.yml)."
}

# Print all network.
function printNetwork() {
	echo "Usage: "
	echo "  pnet.sh <command> <subcommand>"
	echo "      <command> - <command=up|down|restart> corresponding network based on user choice."
	echo "      <subcommand> - one of 'p2p', 'p2s', 'p2sp' or 'so'."
	echo "          - 'p2p' - a peer-to-peer based, private network."
	echo "          - 'p2s' - a peer-to-server based, private network."
	echo "          - 'p2sp' - a peer to server and to peer based, private network."
	echo "          - 'so' - a server-only private network."
	echo
	echo "Typically, one can bring up the network through subcommand e.g.:"
	echo
	echo "      ./pnet.sh up p2p"
	echo
}

# Generate swarm key
function generateKey() {
	which swarmkeygen
	if [ "$?" -ne 0 ]; then
		echo "swarmkeygen tool not found, exit."
		exit 1
	fi
	echo "---- Generate swarm.key file using swarmkeygen tool. ----"
	set -x
	swarmkeygen generate >$BUILD_PATH/swarm.key
	res=$?
	set +x
	if [ $res -ne 0 ]; then
		echo "Failed to generate swarm.key file, exit."
		exit 1
	fi
}

# Docker-compose interface for create containers.
function composeCreate() {
	docker-compose -f $1 up --no-start $CONTAINER
}

# Create containers environment
function createContainers() {
	echo "---- Creat containers for running IPFS. ----"
	if [ "$SUBCOMMAND" == "p2p" ]; then
		for CONTAINER in peer0.example.com peer1.example.com; do
			composeCreate $COMPOSE_FILE_P2P
		done
	elif [ "$SUBCOMMAND" == "p2s" ]; then
		for CONTAINER in peer.example.com server.example.com; do
			composeCreate $COMPOSE_FILE_P2S
		done
	elif [ "$SUBCOMMAND" == "p2sp" ]; then
		for CONTAINER in peer0.example.com peer1.example.com server.example.com; do
			composeCreate $COMPOSE_FILE_P2SP
		done
	else
		for CONTAINER in server0.example.com server1.example.com server2.example.com; do
			composeCreate $COMPOSE_FILE_SO
		done
	fi
}

# Docker cp interface for copying swarm key
function dockerCpSwarmKey() {
	set -x
	docker cp -a $BUILD_PATH/swarm.key $CONTAINER:/var/ipfsfb
	set +x
}

# Docker cp interface for copying IPFS Web UI
function dockerCpWebUI() {
	set -x
	docker cp -a $BUILD_PATH/$WEBUI_CID $CONTAINER:/var/ipfsfb
	set +x
}

# Copy swarm key file into container
function copySwarmKey() {
	echo "---- Copy swarm key file into the container file system. ----"
	if [ "$SUBCOMMAND" == "p2p" ]; then
		for CONTAINER in peer0.example.com peer1.example.com; do
			dockerCpSwarmKey
		done
	elif [ "$SUBCOMMAND" == "p2s" ]; then
		for CONTAINER in peer.example.com server.example.com; do
			dockerCpSwarmKey
		done
	elif [ "$SUBCOMMAND" == "p2sp" ]; then
		for CONTAINER in peer0.example.com peer1.example.com server.example.com; do
			dockerCpSwarmKey
		done
	else
		for CONTAINER in server0.example.com server1.example.com server2.example.com; do
			dockerCpSwarmKey
		done
	fi
}

# Copy Web UI into container.
function copyWebUI() {
	echo "---- Copy IPFS Web UI into the container file system. ----"
	if [ "$SUBCOMMAND" == "p2s" ] || [ "$SUBCOMMAND" == "p2sp" ]; then
		CONTAINER=server.example.com
		dockerCpWebUI
	elif [ "$SUBCOMMAND" == "so" ]; then
		for CONTAINER in server0.example.com server1.example.com server2.example.com; do
			dockerCpWebUI
		done
	else
		echo "---- Skipping p2p copy for Web UI ----"
	fi
}

# Download IPFS Web UI
function downloadWebUI() {
	if [ "$SUBCOMMAND" == "p2p" ]; then
		echo "---- Skipping p2p download for Web UI ----"
	else
		echo "---- Downloading IPFS Web UI from ipfs public gateway ----"
		set -x
		(cd $BUILD_PATH && curl https://$PUBLIC_GATEWAY/api/$API_VERSION/get/$WEBUI_CID | tar -xf -)
		res=$?
		set +x
		if [ $res -ne 0 ]; then
			echo "Failed to download IPFS Web UI, exit."
			exit 1
		fi
	fi
}

# Docker-compose interface for start containers
function composeStart() {
	docker-compose -f $1 start $CONTAINER
}

# Start containers
function startContainers() {
	echo "---- Start containers using secret swarm key. ----"
	if [ "$SUBCOMMAND" == "p2p" ]; then
		for CONTAINER in peer0.example.com peer1.example.com; do
			composeStart $COMPOSE_FILE_P2P
		done
	elif [ "$SUBCOMMAND" == "p2s" ]; then
		for CONTAINER in peer.example.com server.example.com; do
			composeStart $COMPOSE_FILE_P2S
		done
	elif [ "$SUBCOMMAND" == "p2sp" ]; then
		for CONTAINER in peer0.example.com peer1.example.com server.example.com; do
			composeStart $COMPOSE_FILE_P2SP
		done
	else
		for CONTAINER in server0.example.com server1.example.com server2.example.com; do
			composeStart $COMPOSE_FILE_SO
		done
	fi
	echo "---- Sleeping 15s to allow network complete booting. ----"
	sleep 15
}

# Remove all default bootstrap nodes
function removeBootstrap() {
	docker exec $CONTAINER ipfs bootstrap rm --all
}

# Get containers ipfs address
function getAddress() {
	CONTAINER_ADDR=$(docker exec $CONTAINER ipfs id -f='<addrs>' | tail -n 1)
}

# Add bootstarp nodes for the network
function addBootstrap() {
	if [ "$CONTAINER" != "$CNAME" ]; then
		docker exec $CNAME ipfs bootstrap add $CONTAINER_ADDR
	fi
}

# Set and switch to private network, CONTAINER and CNAME are container alias
function switchPrivateNet() {
	echo "---- Configure the private network. ----"
	if [ "$SUBCOMMAND" == "p2p" ]; then
		for CONTAINER in peer0.example.com peer1.example.com; do
			removeBootstrap
		done
		for CONTAINER in peer0.example.com peer1.example.com; do
			getAddress
			for CNAME in peer1.example.com peer0.example.com; do
				addBootstrap
			done
		done
	elif [ "$SUBCOMMAND" == "p2s" ]; then
		for CONTAINER in peer.example.com server.example.com; do
			removeBootstrap
		done
		for CONTAINER in peer.example.com server.example.com; do
			getAddress
			for CNAME in server.example.com peer.example.com; do
				addBootstrap
			done
		done
	elif [ "$SUBCOMMAND" == "p2sp" ]; then
		for CONTAINER in peer0.example.com peer1.example.com server.example.com; do
			removeBootstrap
		done
		for CONTAINER in peer0.example.com peer1.example.com server.example.com; do
			getAddress
			for CNAME in peer1.example.com server.example.com peer0.example.com; do
				addBootstrap
			done
		done
	else
		for CONTAINER in server0.example.com server1.example.com server2.example.com; do
			removeBootstrap
		done
		for CONTAINER in server0.example.com server1.example.com server2.example.com; do
			getAddress
			for CNAME in server1.example.com server2.example.com server0.example.com; do
				addBootstrap
			done
		done
	fi
}

# Docker-compose interface for restart containers
function composeRestart() {
	docker-compose -f $1 restart $CONTAINER
}

# Restart containers for the private network.
function restartContainers() {
	echo "---- Restart containers for the configured private network. ----"
	if [ "$SUBCOMMAND" == "p2p" ]; then
		for CONTAINER in peer0.example.com peer1.example.com; do
			composeRestart $COMPOSE_FILE_P2P
		done
	elif [ "$SUBCOMMAND" == "p2s" ]; then
		for CONTAINER in peer.example.com server.example.com; do
			composeRestart $COMPOSE_FILE_P2S
		done
	elif [ "$SUBCOMMAND" == "p2sp" ]; then
		for CONTAINER in peer0.example.com peer1.example.com server.example.com; do
			composeRestart $COMPOSE_FILE_P2SP
		done
	else
		for CONTAINER in server0.example.com server1.example.com server2.example.com; do
			composeRestart $COMPOSE_FILE_SO
		done
	fi
}

# General interface for up and running a private network.
function networkUp() {
	if [ -d "$BUILD_PATH" ]; then
		generateKey
		downloadWebUI
		createContainers
		copySwarmKey
		copyWebUI
		startContainers
		switchPrivateNet
		restartContainers
	fi
}

# Set and export environment variables from env file
function setEnv() {
	if [ "$SUBCOMMAND" == "p2p" ]; then
		set -a
		source $ENV_P2P
		set +a
	elif [ "$SUBCOMMAND" == "p2s" ]; then
		set -a
		source $ENV_P2S
		set +a
	elif [ "$SUBCOMMAND" == "p2sp" ]; then
		set -a
		source $ENV_P2SP
		set +a
	else
		set -a
		source $ENV_SO
		set +a
	fi
}

# Start and up a peer to peer based private network
function p2pUp() {
	setEnv
	networkUp
	docker-compose -f $COMPOSE_FILE_P2P up -d --no-deps cli 2>&1
	if [ $? -ne 0 ]; then
		echo "ERROR!!! could not start p2p network, exit."
		exit 1
	fi
	# Run end to end tests
	$E2E_TEST $SUBCOMMAND peer0.example.com peer1.example.com
}

# Stop and clear peer to peer based private network
function p2pDown() {
	setEnv
	# Bring down the private network, and remove volumes.
	docker-compose -f $COMPOSE_FILE_P2P down --volumes --remove-orphans
	# Remove local ipfs config.
	rm -rf .ipfs/data .ipfs/staging
	if [ "$COMMAND" != "restart" ]; then
		docker run -v $PWD:/var/ipfsfb --rm ipfsfb/ipfs-tools:$TOOL_IMAGETAG rm -rf /var/ipfsfb/peer /var/ipfsfb/data /var/ipfsfb/staging
		# Remove unwanted key file generated by swarmkeygen tool.
		rm -f $BUILD_PATH/*.key
		# Remove unwanted IPFS Web UI.
		rm -rf $BUILD_PATH/$WEBUI_CID
	fi
}

# Start and up a peer to server based private network
function p2sUp() {
	setEnv
	networkUp
	docker-compose -f $COMPOSE_FILE_P2S up -d --no-deps cli 2>&1
	if [ $? -ne 0 ]; then
		echo "ERROR!!! could not start p2s network, exit."
		exit 1
	fi
	# Run end to end tests
	$E2E_TEST $SUBCOMMAND server.example.com peer.example.com
}

# Stop and clear peer to server based private network
function p2sDown() {
	setEnv
	# Bring down the private network, and remove volumes.
	docker-compose -f $COMPOSE_FILE_P2S down --volumes --remove-orphans
	# Remove local ipfs config.
	rm -rf .ipfs/data .ipfs/staging
	if [ "$COMMAND" != "restart" ]; then
		docker run -v $PWD:/var/ipfsfb --rm ipfsfb/ipfs-tools:$TOOL_IMAGETAG rm -rf /var/ipfsfb/peer /var/ipfsfb/server /var/ipfsfb/data /var/ipfsfb/staging
		# Clean the network cache.
		docker network prune -f
		# Remove unwanted key file generated by swarmkeygen tool.
		rm -f $BUILD_PATH/*.key
		# Remove unwanted IPFS Web UI.
		rm -rf $BUILD_PATH/$WEBUI_CID
	fi
}

# Start and up a peer to server and to peer based private network
function p2spUp() {
	setEnv
	networkUp
	docker-compose -f $COMPOSE_FILE_P2SP up -d --no-deps cli 2>&1
	if [ $? -ne 0 ]; then
		echo "ERROR!!! could not start p2s network, exit."
		exit 1
	fi
	# Run end to end tests
	$E2E_TEST $SUBCOMMAND server.example.com peer0.example.com peer1.example.com
}

# Stop and clear peer to server and to peer based private network
function p2spDown() {
	setEnv
	# Bring down the private network, and remove volumes.
	docker-compose -f $COMPOSE_FILE_P2SP down --volumes --remove-orphans
	# Remove local ipfs config.
	rm -rf .ipfs/data .ipfs/staging
	if [ "$COMMAND" != "restart" ]; then
		docker run -v $PWD:/var/ipfsfb --rm ipfsfb/ipfs-tools:$TOOL_IMAGETAG rm -rf /var/ipfsfb/peer /var/ipfsfb/server /var/ipfsfb/data /var/ipfsfb/staging
		# Clean the network cache.
		docker network prune -f
		# Remove unwanted key file generated by swarmkeygen tool.
		rm -f $BUILD_PATH/*.key
		# Remove unwanted IPFS Web UI.
		rm -rf $BUILD_PATH/$WEBUI_CID
	fi
}

# Start and up a server-only private network
function soUp() {
	setEnv
	networkUp
	docker-compose -f $COMPOSE_FILE_SO up -d --no-deps cli 2>&1
	if [ $? -ne 0 ]; then
		echo "ERROR!!! could not start server-only network, exit."
		exit 1
	fi
	# Run end to end tests
	$E2E_TEST $SUBCOMMAND server0.example.com server1.example.com server2.example.com
}

# Stop and clear server-only private network
function soDown() {
	setEnv
	# Bring down the private network, and remove volumes.
	docker-compose -f $COMPOSE_FILE_SO down --volumes --remove-orphans
	# Remove local ipfs config.
	rm -rf .ipfs/data .ipfs/staging
	if [ "$COMMAND" != "restart" ]; then
		docker run -v $PWD:/var/ipfsfb --rm ipfsfb/ipfs-tools:$TOOL_IMAGETAG rm -rf /var/ipfsfb/server /var/ipfsfb/data /var/ipfsfb/staging
		# Clean the network cache.
		docker network prune -f
		# Remove unwanted key file generated by swarmkeygen tool.
		rm -f $BUILD_PATH/*.key
		# Remove unwanted IPFS Web UI.
		rm -rf $BUILD_PATH/$WEBUI_CID
	fi
}

# Set the network
NETWORK=simple-network
# Use default docker-compose file
COMPOSE_FILE=docker-compose.yml
# Environment file
ENV=.env
# Set end-to-end name space
E2E_NS=e2e
# End-to-end test file
E2E_TEST=$E2E_NS/test.sh
# Set networks docker-compose file
COMPOSE_FILE_P2P=./p2p/${COMPOSE_FILE}
COMPOSE_FILE_P2S=./p2s/${COMPOSE_FILE}
COMPOSE_FILE_P2SP=./p2sp/${COMPOSE_FILE}
COMPOSE_FILE_SO=./so/${COMPOSE_FILE}
# Set environment variable for docker-compose file
ENV_P2P=./p2p/${ENV}
ENV_P2S=./p2s/${ENV}
ENV_P2SP=./p2sp/${ENV}
ENV_SO=./so/${ENV}
# Set image tag
TOOL_IMAGETAG=latest
# Set IPFS public gateway
PUBLIC_GATEWAY=dweb.link
# Set private Web UI cid
WEBUI_CID=QmXc9raDM1M5G5fpBnVyQ71vR4gbnskwnB9iMEzBuLgvoZ
# Set api version
API_VERSION=v0

# Options for running command
while getopts "h?n?i:f:" opt; do
	case "$opt" in
	h | \?)
		printHelper
		exit 0
		;;
	n)
		printNetwork
		exit 0
		;;
	i)
		TOOL_IMAGETAG=$OPTARG
		;;
	f)
		COMPOSE_FILE=$OPTARG
		;;
	esac
done

# The arg of the command
COMMAND=$1
SUBCOMMAND=$2
shift

# Command interface for execution
if [ "${COMMAND}" == "up" ]; then
	if [ "${SUBCOMMAND}" == "p2p" ]; then
		p2pUp
	elif [ "${SUBCOMMAND}" == "p2s" ]; then
		p2sUp
	elif [ "${SUBCOMMAND}" == "p2sp" ]; then
		p2spUp
	elif [ "${SUBCOMMAND}" == "so" ]; then
		soUp
	else
		printNetwork
		exit 1
	fi
elif [ "${COMMAND}" == "down" ]; then
	if [ "${SUBCOMMAND}" == "p2p" ]; then
		p2pDown
	elif [ "${SUBCOMMAND}" == "p2s" ]; then
		p2sDown
	elif [ "${SUBCOMMAND}" == "p2sp" ]; then
		p2spDown
	elif [ "${SUBCOMMAND}" == "so" ]; then
		soDown
	else
		printNetwork
		exit 1
	fi
elif [ "${COMMAND}" == "restart" ]; then
	if [ "${SUBCOMMAND}" == "p2p" ]; then
		p2pDown
		p2pUp
	elif [ "${SUBCOMMAND}" == "p2s" ]; then
		p2sDown
		p2sUp
	elif [ "${SUBCOMMAND}" == "p2sp" ]; then
		p2spDown
		p2spUp
	elif [ "${SUBCOMMAND}" == "so" ]; then
		soDown
		soUp
	else
		printNetwork
		exit 1
	fi
elif [ "${COMMAND}" == "generate" ]; then
	generateKey
else
	printHelper
	exit 1
fi
