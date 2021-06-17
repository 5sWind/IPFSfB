# Private IPFS Web UI

## Enable Downloads

After bringing up one of the four senarios (p2p, p2s, p2sp or so), you can execute [enableDownloads.sh](../../samples/simple-network/scripts/webui/enableDownloads.sh) script to enable download function for private IPFS Web UI. Beacuse by default we enables 0.0.0.0 as the ipfs-server entry point (other addresses would reject and throw errors if an ip address doesn't exist in your machine during the IPFS daemon process), and web ui uses your ip and gateway port to download. So as to download, we must tell the web ui where the resources are from. Thus we should change 0.0.0.0 to our server's public ip address after bootstrap.

## How to run [enableDownloads.sh](../../samples/simple-network/scripts/webui/enableDownloads.sh) at every system reboot

If you configurd [enableDownloads.sh](../../samples/simple-network/scripts/webui/enableDownloads.sh), you might be worrying about the risk of system rebooting, because it will stop all running containers and can't be restarted back into previous status if you have configured and enabled downloads for current Web UI. However, there is a tutorial to teach you how to avoid the risk of losing running containers at system rebooting.

### Use Crontab

For Linux/macOS, the simplest way for enabling downloads is to use crontab for every system reboot.

Open crontab task list by:

```bash
crontab -e
```

Mount server containers config `/var/ipfsfb/config` to local file system's destination and edit api and gateway addresses back to `0.0.0.0` by scripts, and enter:

```bash
@reboot docker start `docker ps -aqf 'name=server'` && $HOME/<your destination to IPFSfB>/samples/simple-network/scripts/webui/enableDownloads.sh
```

This will first change the stopped server containers' status back to normal, and restart all affacted `server` containers, then enable download function to bring it to previous status.
