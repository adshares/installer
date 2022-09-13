<p align="center">
    <a href="https://adshares.net/" title="Adshares sp. z o.o." target="_blank">
        <img src="https://adshares.net/logos/ads.svg" alt="Adshares" width="100" height="100">
    </a>
</p>

<h3 align="center"><small>(DEPRECATED) Adshares / Installer</small></h3>
<br />
<b>Project is DEPRECATED due to incompatible changes in other modules. See https://docs.adshares.net/adserver/how-to-start-adserver.html</b>

## Quick Start (on Ubuntu 18.04)


> ### Prerequisites
> - Existing ADS account (with credentials)
> - A clean Ubuntu/Bionic install
> - You are logged in as a user with `sudo` privileges
> - domain for adserver UI and another for serving ads pointing to server IP (eg. main domain for UI and subdomain for serving ads: example.com and app.example.com)
> - You have mail server ready somewhere (use something like [MailHog](https://github.com/mailhog/MailHog) for local testing)

```bash
apt-get install git
git clone https://github.com/adshares/installer.git
cd installer
sudo -H bin/install.sh
```
> The script above creates a separate `adshares` user (without sudo privileges) to be the owner of all the installed services.

Script will ask you to provide your ADS wallet credentials, so please create ADS account first.

> Note that there are many environment variables you can override to tweak the behavior of the services. 
> Every project has the `.env` file where you can find most of configuration options. 

## Examples:
### Deploy `mailhog`
```bash
docker run --publish 1025:1025 --publish 8025:8025 --detach --restart always mailhog/mailhog
```
### Prepare system dependencies without deploying 
```bash
sudo -H SKIP_SERVICES=1 bin/install.sh
```

### Deploy all services from `develop` branches without reinstalling system dependencies
```bash
sudo -H SKIP_BOOTSTRAP=1 bin/install.sh -b develop
```

### Simple one-liner when you have `installer` in your home dir - this installs all the currently checked out services
```bash
cd ~/installer/ && git pull && sudo -H SKIP_BOOTSTRAP=1 SKIP_CLONE=1 bin/install.sh
```
