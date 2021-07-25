# ab-nginx

Containerized fully-functional implementation of NGINX running on Alpine **as a fully NON-ROOT user**. The container by default is a 'blank slate' that just serves files out of the box. Changing configuration, server blocks and content is accomplished with bind-mounts using a sensible, simple directory structure. The container auto-detects mounted certificates and switches to TLS automatically. [Helper scripts](https://git.asifbacchus.dev/ab-docker/ab-nginx/releases) in the git repo make certificate mounting easier, allow for custom docker networks and more. The container by default can be used as a Let’s Encrypt endpoint with tools like certbot.

## Contents

[Alternate repository](#alternate-repository)<br>
[Documentation and scripts](#documentation-and-scripts)<br>
[Permissions](#permissions)<br>
[Container layout](#container-layout)<br>
	[Content directory](#content-directory)<br>
	[Configuration directory](#configuration-directory)<br>
[Quick-start](#quick-start)<br>
	[Mounting content](#mounting-content)<br>
	[Mounting configurations](#mounting-configurations)<br>
	[Mounting server-blocks](#mounting-server-blocks)<br>
[TLS](#tls)<br>
[Environment variables](#environment-variables)<br>
[Shell mode](#shell-mode)<br>
	[Drop to shell before NGINX loads](#drop-to-shell-before-nginx-loads)<br>
	[Enter a running container](#enter-a-running-container)<br>
[Logs](#logs)<br>
[Final thoughts](#final-thoughts)

## Alternate repository

Throughout this document, I reference my repository on DockerHub (`asifbacchus/ab-nginx:tag`). You may also feel free to pull directly from my private registry instead, especially if you need signed containers. Simply use `docker.asifbacchus.dev/nginx/ab-nginx:tag`. I usually sign major dot-version releases (1.18, 1.19, etc.) as well as the 'latest' image.

## Documentation and scripts

Check out the [repo wiki](https://git.asifbacchus.dev/ab-docker/ab-nginx/wiki) for detailed examples and documentation about the container and the [helper scripts](https://git.asifbacchus.dev/ab-docker/ab-nginx/releases) which are located [here](https://git.asifbacchus.dev/ab-docker/ab-nginx/releases).

## Permissions

The container does **NOT** run under the root account. It runs under a user named *www-docker* with a UID of 8080. **This means any files you mount into the container need to be readable (and/or writable depending on your use-case) by UID 8080**. This does not mean just content files, it also includes configurations, server-blocks and *certificates*! Before mounting your files, ensure this is the case. There are more detailed instructions in the [wiki](https://git.asifbacchus.dev/ab-docker/ab-nginx/wiki) if you need help setting file permissions.

This is a significant change versus most other NGINX implementations/containers where the main process is run as root
and the *worker processes* run as a limited user. In those cases, permissions don’t matter since NGINX can always use
the root account to read any files (and especially certificates!) it needs. Please understand this difference.

If you need to change the UID, then you’ll need to rebuild the container using
the [Dockerfile in the git repo](https://git.asifbacchus.dev/ab-docker/ab-nginx). The process would be something like
this:

```bash
# clone the repo
git clone https://git.asifbacchus.dev/ab-docker/ab-nginx

# change to the proper directory and build the container
cd ab-nginx/build
docker build --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') --build-arg UID=xxxx -t name:tag .
```

Of course, replace *xxxx* with your desired UID for the *www-docker* user. Also, replace *name:tag* with whatever you want to tag your image.

## Container layout

### Content directory

All content is served from the NGINX default `/usr/share/nginx/html` directory within the container. The default set up serves everything found here and in all child directories. To use your own content (this point of this whole thing, right? :wink:) bind-mount your content to the container’s webroot: `-v /my/webstuff:/usr/share/nginx/html`. **Remember that UID 8080 must be able to read these files!**

### Configuration directory

All configuration is in the `/etc/nginx` directory and its children. Here is the layout of that directory within the container:

```text
/etc/nginx
├── config
│   └── **add configuration files here or replace the whole directory**
├── sites
│   ├── 05-nonsecured.conf
│   ├── 05-secured.conf.disabled
│   └── **add additional server-block files or replace whole directory**
├── ssl-config
│   ├── mozIntermediate_ssl.conf.disabled
│   └── mozModern_ssl.conf.disabled
	 └── (SSL configuration – container manages this)
├── errorpages.conf – (pre-configured fun error pages, you can override)
├── health.conf – (health-check endpoint, best to not touch this)
├── nginx.conf – **main NGINX configuration file, replace if really necessary**
├── server_names.conf – (list of hostnames, updated via environment variable)
├── ssl_certs.conf – (hard-coded for the container, best not to touch)
```

Locations with \**starred descriptions** are designed to be overwritten via bind-mounts to customize the container. For more details on all of these files and what they do, please refer to the [repo wiki](https://git.asifbacchus.dev/ab-docker/ab-nginx/wiki). **Remember that UID 8080 needs to be able to read any files you choose to bind-mount over the container defaults!**

## Quick-start

At it’s most basic, all you need to do is mount a directory with content to serve. For more advanced deployments, you can also mount various configurations. In most cases, you’ll also want to mount certificates so that SSL/TLS is an option. **Remember that UID 8080 must be able to read everything you bind-mount!** Let’s run through some examples:

### Mounting content

Simply bind-mount whatever you want served to `/usr/share/nginx/html`:

```bash
docker run -d --name ab-nginx --restart unless-stopped \
  -p 80:80 \
  -v ~/web:/usr/share/nginx/html \
  asifbacchus/ab-nginx
```

### Mounting configurations

Any *.conf* files found in `/etc/nginx/config` will be loaded after *nginx.conf* and thus, take precedence. All config files are read into the HTTP-context. Please note: **only files ending in .conf** will be read by the container!

I suggest dividing your configurations into various files organized by type (i.e. headers.conf, buffers.conf, timeouts.conf, etc.) and putting them all into one directory and bind-mounting that to the container:

```bash
docker run -d --name ab-nginx --restart unless-stopped \
  -p 80:80 \
  -v ~/web:/usr/share/nginx/html \
  -v ~/nginx/config:/etc/nginx/config:ro \
  asifbacchus/ab-nginx
```

If you need to change configuration settings, make the changes on the host and save the file(s). Then, restart the container to apply the change:

```bash
docker restart ab-nginx
```

If you want the container to ignore a specific set of configuration options, say you’re testing something, then rename the file with those configuration options using any extension other than *.conf*. I usually use *.conf.disabled*. Restart the container and that file will be ignored.

More details and examples are found in the [wiki](https://git.asifbacchus.dev/ab-docker/ab-nginx/wiki).

### Mounting server-blocks

If you just want to serve static content from your content/webroot directory, then you can ignore this section entirely :smile:.

Otherwise, any files found in the `/etc/nginx/sites` directory in the container will be loaded after the configuration files. These files are meant to define the *SERVER*-context. The container has both a secure and non-secure default server block that simply serves everything found in the webroot. Depending on your SSL configuration, the container enables the correct block. You can add additional server blocks or you can override these default servers entirely by bind-mounting over the directory:

```bash
# add another server block definition that listens on port 8080
docker run -d --name ab-nginx --restart unless-stopped \
  -p 80:80 \
  -p 8080:8080 \
  -v ~/web:/usr/share/nginx/html \
  -v ~/webapp.conf:/etc/nginx/sites/webapp.conf:ro \
  asifbacchus/ab-nginx

# override default server-blocks entirely (use your own)
docker run -d --name ab-nginx --restart unless-stopped \
  -p 80:80 \
  -v ~/web:/usr/share/nginx/html \
  -v ~/nginx/servers:/etc/nginx/sites:ro \
  asifbacchus/ab-nginx
```

More details and examples are found in the [wiki](https://git.asifbacchus.dev/ab-docker/ab-nginx/wiki).

## TLS

The container will automatically update its configuration to use provided certificates. The examples below assume you have all required files in one directory, but you can also mount them all separately. The required files and their locations in the container are:

| file type                                                    | container-location   |
| ------------------------------------------------------------ | -------------------- |
| Full-chain certificate<br />(certificate concatenated with intermediates and root CA) | /certs/fullchain.pem |
| Private key                                                  | /certs/privkey.pem   |
| Certificate chain<br />(intermediates concatenated with root CA) | /certs/chain.pem     |
| DH Parameters file<br />(NOT required for TLS 1.3-only mode) | /certs/dhparam.pem   |

Once those files are available, you can run the container as follows:

```bash
# TLS 1.2 (requires: fullchain.pem, privkey.pem, chain.pem and dhparam.pem)
docker run -d --name nginx --restart unless-stopped \
  -p 80:80 \
  -p 443:443 \
  -v ~/web:/usr/share/nginx/html \
  -v ~/certs:/certs:ro \
  -e SERVER_NAMES="domain.tld www.domain.tld" \
  asifbacchus/ab-nginx:latest

# TLS 1.3 only mode (requires fullchain.pem, privkey.pem and chain.pem)
docker run -d --name nginx --restart unless-stopped \
  -p 80:80 \
  -p 443:443 \
  -v ~/web:/usr/share/nginx/html \
  -v ~/certs:/certs:ro \
  -e SERVER_NAMES="domain.tld www.domain.tld" \
  -e TLS13_ONLY=TRUE
  asifbacchus/ab-nginx:latest
```

The container will load a secure configuration automatically, require SSL connections and redirect HTTP to HTTPS. If you want to enforce HSTS, simply set the HSTS environment variable to true by adding `-e HSTS=TRUE` before specifying the container name. Careful about doing this while testing though! Also, certificates should always be mounted read-only (`:ro`) for security reasons!

You may have noticed I also specified the `SERVER_NAMES` variable. This is necessary or SSL will not work since the hostname the server responds to must match the certificate being presented. **Make sure you set this environment variable to match your certificates!** N.B. If you are using your own server-blocks, then this environment variable is **NOT** required – it is only used by the container when auto-configuring the default server-blocks.

If you want to integrate with Let's Encrypt, please refer to the [wiki](https://git.asifbacchus.dev/ab-docker/ab-nginx/wiki).

Finally, I’d remind you once again that UID 8080 must be able to read your certificate files! It is common practice to restrict the private key to root readability only (i.e. chown root:root & chmod 600/400) but, that would stop the NGINX user in the container from reading it and NGINX will exit with an error. I address ways to allow your certificate files to remain secure but still readable by the NGINX user in the [wiki](https://git.asifbacchus.dev/ab-docker/ab-nginx/wiki).

## Environment variables

You can set several options simply by passing environment variables. They are pretty self-explanatory but here is a summary:

| name         | description                                                  | default                     | permitted values         |
| ------------ | ------------------------------------------------------------ | --------------------------- | ------------------------ |
| TZ           | Set the container time zone for proper logging.              | Etc/UTC                     | Valid IANA TZ values     |
| SERVER_NAMES | Space-delimited list of hostnames/FQDNs to which NGINX should respond. Must be "enclosed in quotes". This is only used by the default configuration and would not be applicable if you are using your own server blocks, unless you choose to reference the `/etc/nginx/server_names.conf` file.<br />If you are using the default configuration and SSL, remember this *must* match your SSL certificates! The default value will only work for for HTTP connections! | "_" (this means "anything") | Valid IANA hostnames     |
| HTTP_PORT    | Port on which HTTP connections should be accepted. If you set this, make sure you set your port mapping properly! For example, if you set this to 8080 then you need to specify `-p 8080:8080` or something like `-p 12.34.567.89:8080:8080`. In most cases, you don’t need this and should only change the host port mapping. For example `-p 8080:80`. | 80                          | Valid unused ports       |
| HTTPS_PORT   | Port on which HTTPS connections should be accepted. If you set this, make sure you set your port mapping properly! For example, if you set this to 8443 then you need to specify `-p 8443:8443` or something like `-p 12.34.567.89:8443:8443`. In most cases, you don’t need this and should only change the host port mapping. For example `-p 8443:443`. | 443                         | Valid unused ports       |
| ACCESS_LOG   | Turn on/off access logging. The default format is the same as the NGINX default: *combined*. You can specify your own format via configuration files and use it in custom server blocks. | OFF                         | `ON`, `OFF`              |
| HSTS         | Activate the HSTS header. Please be sure you know what this means and that your SSL configuration is correct before enabling! The default configuration sets an HSTS max-age of 15768000s (6 months). | FALSE                       | Boolean: `TRUE`, `FALSE` |
| TLS13_ONLY   | Activate the container's TLS 1.3 configuration. This is a strict TLS 1.3 implementation and does *not* fall back to TLS 1.2. If you still need to support TLS 1.2, then leave this turned off. The TLS 1.2 configuration *does* upgrade to TLS 1.3 where possible. | FALSE                       | Boolean: `TRUE`, `FALSE` |

## Shell mode

Running the container in shell mode is a great way to verify configurations, make sure everything mounted correctly or to see what the defaults are. You have two options: drop to shell before NGINX loads or after.

### Drop to shell before NGINX loads

This is useful to verify where things mounted, etc. This is also useful if some configuration is causing NGINX to panic and shutting down the container. Note that I’m using the `--rm` flag to auto-remove the container when I exit since there is no point in keeping a shell-mode instantiation around.

```bash
docker run -it --rm \
  -v ~/web:/usr/share/nginx/html \
  -v ~/nginx/config:/etc/nginx/config \
  -v ~/nginx/servers:/etc/nginx/sites \
  -v ~/certs:/certs \
  asifbacchus/ab-nginx /bin/sh
```

### Enter a running container

If you want to enter a running container and check things out:

```
docker exec -it ab-nginx /bin/sh
```

Remember this container is running Alpine Linux and the shell is ASH. You do *not* have all the bells and whistles of BASH! Also, many commands are run via busybox, so some things may not work exactly like you might be used to in a Debian/Ubuntu environment, for example. As a side note, *ping* is installed and fully functional in this container so that makes troubleshooting a little easier.

## Logs

The container logs everything to stdout and stderr – in other words, the console. To see what’s going on with NGINX simply use docker’s integrated logging features from the host:

```bash
# default log lookback
docker logs ab-nginx

# last 50 lines
docker logs -n 50 ab-nginx

# show last 10 lines and follow from there in realtime (ctrl-c to stop)
docker logs -n 10 -f ab-nginx
```

## Final thoughts

I think that's everything to get you going if you are already familiar with docker and with NGINX in general. If you need more help, please [refer to the wiki](https://git.asifbacchus.dev/ab-docker/ab-nginx/wiki). I've explained everything there in detail. Also, check out the [helper scripts](https://git.asifbacchus.dev/ab-docker/ab-nginx/releases) especially if you are deploying certificates. The scripts take care of all the docker command-lines for you so you have much less typing!

If I've forgotten anything, you find any bugs or you have suggestions, please file an issue either on my private [git server ](https://git.asifbacchus.dev/ab-docker/ab-nginx) or on [github](https://github.com/asifbacchus/ab-nginx). Also, I am *not* affiliated with NGINX in any way, so please **do not** bother them with any issues you find with this container. Bother me instead, I actually enjoy it!

**All the best and have fun!**
