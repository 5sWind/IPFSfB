set -x
PUBLIC_IP_ADDRESS=$(timeout 2 curl ifconfig.co)
if [ "$?" -ne 0 ]; then
    echo "requesting address timed out, exit."
    exit 1
fi
CONTAINERS=$(docker ps -qf 'name=server')
if [ "$?" -ne 0 ]; then
    echo "grabing running server containers failed, exit."
    exit 1
fi
for CONTAINER in $CONTAINERS; do
    docker exec $CONTAINER ipfs config Addresses.API /ip4/$PUBLIC_IP_ADDRESS/tcp/5001
    docker exec $CONTAINER ipfs config Addresses.Gateway /ip4/$PUBLIC_IP_ADDRESS/tcp/8080
done
set +x