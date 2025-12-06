
# [All the Mods 10-5.3.1](https://www.curseforge.com/minecraft/modpacks/all-the-mods-10) on Curseforge
<!-- toc -->

- [Description](#description)
- [Requirements](#requirements)
- [Options](#options)
  * [Adding Minecraft Operators](#adding-minecraft-operators)
- [Troubleshooting](#troubleshooting)
  * [Accept the EULA](#accept-the-eula)
  * [Permissions of Files](#permissions-of-files)
  * [Resetting](#resetting)
- [Source](#source-original-atm9-repo)

<!-- tocstop -->

## Description

This container is built to run on an [Unraid](https://unraid.net) server; outside of that, your mileage will vary.


The Docker on the first run will download the same version as tagged `All the Mods 10-5.3.1` and install it.  This can take a while as the Forge installer can take a bit to complete.  You can watch the logs, and it will eventually finish.

After the first run, it will simply start the server.

Note: There are no modded Minecraft files shipped in the container; they are all downloaded at runtime.

## Requirements

* /data mounted to a persistent disk
* Port 25565/tcp mapped
* environment variable EULA set to "true"

As the end user, you are responsible for accepting the EULA from Mojang to run their server; by default, in the container, it is set to false.

## Manual Installation (Importing into Unraid manually)

Unraid Template Link - [Here](https://github.com/r14f/unraid/blob/main/allthemods10_server.xml)
- Download the XML (Top right, 3 dots, click download)
- Log into your Unraid web GUI.
- Go to the Docker tab.
- Click the dropdown arrow next to Add Container (top right) → select User Templates.
- Click "Import a template" (or if you see "Add new template" → "From URL" or file upload option; Unraid 6.12+ has a direct file import).
- Browse to your downloaded allthemods10_server.xml file and upload/import it.
- Unraid will validate and add it as a new template under User Templates (it'll show up like any CA app, named something like "AllTheMods10 Server").

## Options

These environment variables can be set to override their defaults.

* JVM_OPTS "-Xms2048m -Xmx4096m"
* MOTD "All the Mods 10-5.3.1 Server Powered by Docker"
* ALLOW_FLIGHT "true" or "false"
* MAX_PLAYERS "5"
* ONLINE_MODE "true" or "false"
* ENABLE_WHITELIST "true" or "false"
* WHITELIST_USERS "TestUserName1, TestUserName2"
* OP_USERS "TestUserName1, TestUserName2"

## Troubleshooting

### Accept the EULA
Did you pass in the environment variable EULA set to `true`?

### Permissions of Files
This container is designed for [Unraid](https://unraid.net), so the user running in the container has a UID of 99 and a GID of 100.  This may cause permission errors on the /data mount on other systems.

### Resetting
If the installation is incomplete for some reason.  Deleting the downloaded server file in /data will restart the install/upgrade process.

## Source (Original ATM10 repo)

Github: https://github.com/W3LFARe/docker-allthemods10 <br />
Docker: https://registry.hub.docker.com/r/w3lfare/allthemods10 <br />

## Source / Fork

Github: https://github.com/RFlor14/docker-allthemods10 <br />
Docker: https://hub.docker.com/repository/docker/r14f/allthemods10 <br />

