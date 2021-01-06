# ab-nginx

Containerized fully-functional implementation of NGINX running on Alpine. The container is by default a 'blank slate' that just serves files out of the box. Changing configuration, server blocks and content is accomplished with simple bind-mounts using a sensible, simple directory structure. Coupled with the [helper scripts](https://git.asifbacchus.app/ab-docker/ab-nginx/releases), certificates can be automatically configured with no user interaction required or easily set to work with Let's Encrypt.

## Contents

- [Alternate repository](#alternate-repository)
- [Documentation and scripts](#documentation-and-scripts)
- [Directory layout](#directory-layout)
- [Quick-start](#quick-start)
    - [Basic server](#basic-server)
    - [TLS](#TLS)
    - [Custom configuration](#custom-configuration)
    - [Custom server blocks](#custom-server-blocks)
- [Shell mode](#shell-mode)
- [Environment variables](#environment-variables)
- [Final thoughts](#final-thoughts)

## Alternate repository

Throughout this document, I will reference the repository on DockerHub (`asifbacchus/ab-nginx:tag`). If you want access to perhaps slightly newer releases or need signed containers, feel free to pull them directly from my private registry instead. Simply use `docker.asifbacchus.app/nginx/ab-nginx:tag`. I usually sign major dot-version releases (1.18, 1.19, etc.) as well as the 'latest' image.

## Documentation and scripts

Check out the [repo wiki](https://git.asifbacchus.app/ab-docker/ab-nginx/wiki) for detailed examples and documentation about the container and the [helper scripts](https://git.asifbacchus.app/ab-docker/ab-nginx/releases) which are located [here](https://git.asifbacchus.app/ab-docker/ab-nginx/releases).

## Directory layout

You only need to be concerned with two directories. All content is in */usr/share/nginx/html* and all configuration is in */etc/nginx*. The content layout is obviously completely up to you. The configuration layout is as below:

```text
/etc/nginx
├── config
│   └── **add configuration files here or replace the whole directory**
├── sites
│   ├── 05-test_nonsecured.conf
│   ├── 05-test_secured.conf.disabled
│   └── **add additional server blocks files or replace whole directory**
├── ssl-config
│   ├── mozIntermediate_ssl.conf.disabled
│   └── mozModern_ssl.conf.disabled
	 └── (SSL configuration – container auto-handles this)
├── errorpages.conf – (pre-configured fun error pages, you can override )
├── health.conf – (health-check endpoint, best to not touch this)
├── nginx.conf – **main NGINX configuration file, replace if desired**
├── server_names.conf – (list of hostnames, updated via environment variable)
├── ssl_certs.conf – (container auto-manages this file too)
```

Locations with \**starred descriptions** are designed to be overwritten via bind-mounts to customize the container. For more details on all of these files and what they do, please refer to the [repo wiki](https://git.asifbacchus.app/ab-docker/ab-nginx/wiki).

## Quick-start

At its most basic, you only need to mount a directory with content to serve. If you want, you can also provide custom site and server configurations via bind-mounts. Let's run through a few examples:

### Basic server

The container will serve static content found at the NGINX default location of */usr/share/nginx/html* in the container.

```bash
docker run -d --name nginx --restart unless-stopped \
  -v /myWebsite/content:/usr/share/nginx/html \
  asifbacchus/ab-nginx:latest  
```

### TLS

The container will automatically update its configuration to use provided certificates. Simply mount them, as separate PEM files, in */certs*. The examples below assume you have all required files in one directory, but you can also mount them all separately. The required files and their locations in the container are:

| file type                                                    | container-location   |
| ------------------------------------------------------------ | -------------------- |
| Full-chain certificate<br />(certificate concatenated with intermediates and/or root CA) | /certs/fullchain.pem |
| Private key                                                  | /certs/privkey.pem   |
| Certificate chain (intermediates concatenated with root CA)  | /certs/chain.pem     |
| DH Parameters file (NOT required for TLS 1.3-only mode)      | /certs/dhparams.pem  |

Once those files are available, you can run the container as follows:

```bash
# TLS 1.2 (requires: fullchain.pem, privkey.pem, chain.pem and dhparam.pem)
docker run -d --name nginx --restart unless-stopped \
  -v /myWebsite/content:/usr/share/nginx/html \
  -v /myCerts:/certs:ro \
  -e SERVER_NAMES="domain.tld www.domain.tld" \
  asifbacchus/ab-nginx:latest

# TLS 1.3 only mode (requires fullchain.pem, privkey.pem, chain.pem)
docker run -d --name nginx --restart unless-stopped \
  -v /myWebsite/content:/usr/share/nginx/html \
  -v /myCerts:/certs:ro \
  -e SERVER_NAMES="domain.tld www.domain.tld" \
  -e TLS13_ONLY=TRUE
  asifbacchus/ab-nginx:latest
```

The container will load a secure configuration automatically and require SSL connections. If you want to enforce HSTS, simply set the HSTS environment variable to true by adding `-e HSTS=TRUE` before specifying the container name. Careful about doing this while testing though! Also, certificates should always be mounted read-only (`:ro`) for security reasons!

You may have noticed I also specified the `SERVER_NAMES` variable. This is necessary or SSL will not work since the hostname the server responds to must match the certificate being presented. **Make sure you set this environment variable to match your certificates!**

If you want to integrate with Let's Encrypt, please refer to the [wiki](https://git.asifbacchus.app/ab-docker/ab-nginx/wiki).

### Custom configuration

The container ships as a nearly blank-slate with only NGINX default configurations for everything except SSL which is designed to be automatically handled. The [helper scripts](https://git.asifbacchus.app/ab-docker/ab-nginx) auto-load a sensible fully preconfigured general server environment complete with reasonable settings for things like security headers, proxy settings, timeouts and buffers.

Using your own settings is very simple too! Simple bind-mount your configuration files to */etc/nginx/config* and any files will be read into the configuration. If you want to override *nginx.conf*, just bind-mount on top of that at */etc/nginx/nginx.conf*.

```bash
# add custom configuration files via directory mounting
docker run -d --name nginx --restart unless-stopped \
  -v /myWebsite/content:/usr/share/nginx/html \
  -v /myWebsite/myConfigs:/etc/nginx/config:ro \
  asifbacchus/ab-nginx:latest

# replace nginx.conf and add custom configurations
docker run -d --name nginx --restart unless-stopped \
  -v /myWebsite/content:/usr/share/nginx/html \
  -v /myWebsite/myConfigs:/etc/nginx/config:ro \
  -v /myWebsite/nginx.conf:/etc/nginx/nginx.conf:ro \
  asifbacchus/ab-nginx:latest
```

You might notice that I've been mounting configurations as read-only (`:ro`). This is a safety precaution but is not strictly necessary.

### Custom server blocks

If you only want to serve static assets from the webroot directory, then you can just stick with the defaults. If you'd like to specify your own server blocks for particular applications, you can easily overwrite the container defaults with as many server blocks as you'd like. Just put each one in a separate file, all in one directory, and bind-mount it in the container at */etc/nginx/sites*:

```bash
docker run -d --name nginx --restart unless-stopped \
  -v /myWebsite/content:/usr/share/nginx/html \
  -v /myWebsite/serverBlocks:/etc/nginx/sites:ro \
  asifbacchus/ab-nginx:latest
```

Remember that NGINX processes files in order, so you might want to number your configurations! For example, `00-redirect_to_ssl`, `10-letsEncrypt`, `20-mySite`, etc.

## Shell mode

Running the container in shell mode as a great way to verify configurations or just to see what the defaults are. This will apply all configurations but will *not* actually start NGINX. This lets you browse all mounted locations, make sure everything is where you want it, etc.

```bash
docker run -it --rm \
  -v /myWebsite/content:/usr/share/nginx/html \
  -v /myWebsite/myConfigs:/etc/nginx/config:ro \
  -v /myWebsite/serverBlocks:/etc/nginx/sites:ro \
  -v /myWebsite/certs:/certs:ro \
  -e TLS13_ONLY=TRUE \
  asifbacchus/ab-nginx:latest /bin/sh
```

Remember that this container is running Alpine linux, so the shell is ASH. You do *not* have all the bells and whistles of BASH! Also, many commands are run via busybox, so some things may not work exactly like you might be used to in a Debian/Ubuntu environment, for example. As a side note, *ping* is installed and fully functional in this container so that makes troubleshooting a little easier.

## Environment variables

You can set several options simply by passing environment variables. They are pretty self-explanatory but examples and more details are available in the [wiki](https://git.asifbacchus.app/ab-docker/ab-nginx/wiki). Here's a list of them:

| name         | description                                                  | default                     |
| ------------ | ------------------------------------------------------------ | --------------------------- |
| TZ           | Set the container time zone for proper logging.              | Etc/UTC                     |
| SERVER_NAMES | Space-delimited list of hostnames/FQDNs to which NGINX should respond. This can be overridden via individual server blocks. Must be "enclosed in quotes". | "_" (this means "anything") |
| HTTP_PORT    | Port on which HTTP connections should be accepted. If you set this, make sure you set your port mapping properly! For example, if you set this to 8080 then you need to specify `-p 8080:8080` or something like `-p 12.34.567.89:8080:8080`. | 80                          |
| HTTPS_PORT   | Port on which HTTPS connections should be accepted. If you set this, make sure you set your port mapping properly! For example, if you set this to 8443 then you need to specify `-p 8443:8443` or something like `-p 12.34.567.89:8443:8443`. | 443                         |
| ACCESS_LOG   | Turn on/off access logging. There is a default format specified in the container's *nginx.conf*, but you can override this via configuration files. | off                         |
| HSTS         | Activate the HSTS header. Please be sure you know what this means and that your SSL configuration is correct before enabling! | FALSE                       |
| TLS13_ONLY   | Activate the container's default TLS 1.3 configuration. This is a strict TLS 1.3 implementation and does *not* fall back to TLS 1.2. If you still need to support TLS 1.2, then leave this turned off. The TLS 1.2 configuration *does* upgrade to TLS 1.3 where possible. | FALSE                       |

## Final thoughts

I think that's everything to get you going if you are already familiar with docker and with NGINX in general. If you need more help, please [refer to the wiki](https://git.asifbacchus.app/ab-docker/ab-nginx/wiki). I've explained everything there in detail. Also, check out the [helper scripts](https://git.asifbacchus.app/ab-docker/ab-nginx/releases) especially if you are deploying certificates. The scripts take care of all the docker command-lines for you so you have much less typing!

If I've forgotten anything, you find any bugs or you have suggestions, please file an issue either on my private [git server ](https://git.asifbachus.app/ab-docker/ab-nginx) or on [github](https://github.com/asifbacchus/ab-nginx). Also, I am *not* affiliated with NGINX in any way, so please **do not** bother them with any issues you find with this container. Bother me instead, I actually enjoy it!

All the best and have fun!

