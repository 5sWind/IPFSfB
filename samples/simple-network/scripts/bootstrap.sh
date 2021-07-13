# A script to download binaries and tools, and install docker images for the simple network scenarios

# Match the latest image version if not specified
export IMAGE_VERSION=latest

printHelper() {
	echo "Usage: "
	echo "  bootstrap.sh [<imageversion>] [-h -d -b -t]"
	echo "Flags: "
	echo "  -h - print help message."
	echo "  -d - bypass download of docker images for the specific network."
	echo "  -b - bypass download of network-specific binaries."
	echo "  -t - bypass download of network-specific tools."
	echo
	echo "Typically, you can set the executive environment by running the script e.g.:"
	echo "      bootstrap.sh 0.1.0"
	echo
}

# Check directory to install binaries
DIR=$(basename $PWD)

# Install in samples folder may cause 'directory not empty'
if [ "$DIR" == "samples" ]; then
	echo
	echo "You should run this script in anywhere except the 'samples' folder, exit."
	echo
	exit 1
fi

dockerIPFSfBPull() {
	local IMAGE_TAG=$1
	echo "IPFSfB $NETWORK image: tools, node"
	echo
	docker pull ipfsfb/ipfs-tools:$IMAGE_VERSION
	if [ "$IMAGE_VERSION" != "latest" ]; then
		docker tag ipfsfb/ipfs-tools:$IMAGE_VERSION ipfsfb/ipfs-tools:latest
	fi
	for IMAGE_TAG in peer server; do
		docker pull ipfsfb/ipfs-node:$IMAGE_TAG
	done
}

dockerInstall() {
	which docker
	DOCKER_CHECK=$?
	if [ "$DOCKER_CHECK" == 0 ]; then
		echo "Pulling IPFSfB $NETWORK images..."
		dockerIPFSfBPull $IMAGE_TAG
		echo
		echo "Listing out IPFSfB $NETWORK images..."
		docker images | grep ipfsfb/*
		echo
	else
		echo "-------------------------------------------------------------------------------"
		echo "---- Docker not found, bypassing download of IPFSfB $NETWORK images. ----------"
		echo "-------------------------------------------------------------------------------"
	fi
}

binaryDownload() {
	local BRANCH=$1
	if [ -w $PWD ]; then
		echo "---- Create folder and download $NETWORK binary. ----"
		echo
		mkdir -p $NETWORK
		cd $NETWORK
		git init
		git config core.sparseCheckout true
		git remote add origin -f https://${PROJECT_PATH}
		echo samples/${NETWORK}/* >.git/info/sparse-checkout
		git checkout $BRANCH
		mv samples/${NETWORK}/* $PWD
		rm -rf samples
		mkdir bin .ipfs
		mv ${GOBIN}/swarmkeygen $PWD/bin
	else
		echo "--------------------------------------------------------------------------------"
		echo "---- Permission denied for creating folder and downloading $NETWORK binary. ----"
		echo "--------------------------------------------------------------------------------"
		exit 1
	fi
}

binaryInstall() {
	which git
	GIT_CHECK=$?
	if [ "$GIT_CHECK" == 0 ]; then
		echo "Downloading IPFSfB $NETWORK binary..."
		binaryDownload $BRANCH
	else
		echo "----------------------------------------------------------------------------"
		echo "---- Git not found, bypassing download of IPFSfB $NETWORK binary. ----------"
		echo "----------------------------------------------------------------------------"
	fi
}

toolDownload() {
	if [ -n "$GOPATH" ]; then
		go get -u $PROJECT_PATH/cmd/swarmkeygen
	else
		echo "----------------------------------------------------------------------------"
		echo "----- GOPATH is not set, bypassing download of IPFSfB $NETWORK tools. ------"
		echo "----------------------------------------------------------------------------"
	fi
}

toolInstall() {
	which go
	GO_CHECK=$?
	if [ "$GO_CHECK" == 0 ]; then
		echo "Downloading IPFSfB $NETWORK tools..."
		toolDownload
	else
		echo "----------------------------------------------------------------------------"
		echo "---- Go not found, bypassing download of IPFSfB $NETWORK tools. ------------"
		echo "----------------------------------------------------------------------------"
	fi
}

NETWORK=simple-network
ORG=IBM
PROJECT_NAME=IPFSfB
PROJECT_PATH=github.com/${ORG}/${PROJECT_NAME}
BRANCH=master
GOBIN=${GOPATH}/bin

DOCKER=true
BINARIES=true
TOOLS=true

IMAGE_VERSION=$1
shift

while getopts "h?dbt" opt; do
	case "$opt" in
	h | \?)
		printHelper
		exit 0
		;;
	d)
		DOCKER=false
		;;
	b)
		BINARIES=false
		;;
	t)
		TOOLS=false
		;;
	esac
done

if [ "$DOCKER" == true ]; then
	echo "Installing IPFSfB $NETWORK docker images."
	echo
	dockerInstall
fi
if [ "$TOOLS" == true ]; then
	echo "Installing IPFSfB $NETWORK tools."
	echo
	toolInstall
fi
if [ "$BINARIES" == true ]; then
	echo "Installing IPFSfB $NETWORK binaries."
	echo
	binaryInstall
fi
