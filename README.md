<p align="center">
    <a href="https://adshares.net/" title="Adshares sp. z o.o." target="_blank">
        <img src="https://adshares.net/logos/ads.svg" alt="Adshares" width="100" height="100">
    </a>
</p>

<h3 align="center"><small>Adshares / Installer</small></h3>

## Quick Start (on Ubuntu 18.04)
> ### Prerequisites
> - Existing ADS account (with credentials)
> - A clean Ubuntu/Bionic install
> - You are logged in as a user with `sudo` privileges
> - You have mail server ready somewhere (use something like [MailHog](https://github.com/mailhog/MailHog) for local testing)

```bash
git clone https://github.com/adshares/installer.git
sudo installer/install.sh
```
> The script above creates a separate `adshares` user (without sudo privileges) to be the owner of all the installed services.

Script will ask you to provide your ADS wallet credentials, so please create ADS account first.

> Note that there are many environment variables you can override to tweak the behavior of the services. 
> Every project has the `.env` file where you can find most of configuration options. 
