title: Replacing The Google Cloud Container Startup Agent
date: 2025-07-24
css: style.css
tags: gcp containers


## Replacing The Google Cloud Container Startup Agent

I have a cloud cost reporting batch job that has been running every morning for many years. It emails us a cost summary of our GCP Subaccounts and Azure Subscriptions daily. In this way we reduce the chances of the infinite scalability of the cloud coming into conflict with the finite scalability of our wallets.

For Enterprise Reasons, it's more convenient if it runs from a static internal IP, so it runs on straight GCE, using instance schedules to start it every morning and shut it down shortly after. On boot, a reporting container starts and runs to completion and then the day's work is done.

If I wanted to rearchitect, I'd probably look at running it in Cloud Batch with a reserved IP attached, but at this point, it runs stably for a dollar or two per month, so it's not a priority.

It has always run on [Google Container-Optimized OS](https://cloud.google.com/container-optimized-os/docs) aka COS and started the reporting container using Google's [Container Startup Agent](https://github.com/GoogleCloudPlatform/konlet) aka konlet. To date this was a built-in feature of GCE where if you set the right metadata on an instance, konlet would do the rest. However konlet is now deprecated.

COS itself is a neat project which I wish was more available in the wider world. It's broadly similar to CoreOS, being a stripped down, partially immutable, auto updating container host Linux distro. Like all such distros it's quirky, but in general I have found it simple and extremely low maintenance. It's a good example of the quality engineering and good taste I expect from GCP at its best.

The removal of konlet is years away. But, when I got the deprecation email, I decided it would be fun to get this out of the way, so I jumped in. I used the docs I could find at that time, which provided a simple example of replacing konlet with cloud-init and systemd.

There are now comprehensive [docs here](https://cloud.google.com/container-optimized-os/docs/how-to/run-container-instance) which look broadly like my solution. Finding this link earlier would have saved me some time, but it was a good learning experience and I am preserving my solution here as a slightly different example. Nevertheless I recommend you use that link.

The one advantage of my solution, which you could adapt into Google's example, is that I am configuring docker on COS to use [user namespace remapping](https://docs.docker.com/engine/security/userns-remap/) by default. This is a security enhancement where docker remaps UID/GIDs inside the running container to unprivileged high UID/GIDs on the host. dockerd still runs as root, and in some sense it's halfway between traditional docker and rootless docker. I like it because it's easy to adopt, but for greenfield deploys I prefer to use purely rootless and daemonless podman. 

You may also notice that my systemd service definition is simpler than Google's, but this is just a side effect of my container running to completion and exiting. Docker is run with ```--rm```, so once the container has exited, there is no container to remove. I am also passing ```--pull=always``` to replace konlet's checking for updated images before running.

In the end, all I had to do was to remove the konlet instance metadata and add instance metadata containing cloud-init yaml. Cloud-init then configures docker and creates a systemd service which broadly does the same thing as konlet. My changed Terraform and my cloud-init.yml are below.

## Terraform Change

In a ```google_compute_instance``` resource:

```
metadata = { 
    user-data              = file("cloud-init.yml")
    # removed gce-container-declaration = my-konlet-data
}
```

## Cloud-init to configure docker and replace konlet

```
#cloud-config

write_files:
- path: /etc/systemd/system/billingcontainer.service
  permissions: 0644
  owner: root
  content: |
    [Unit]
    Description=Start the billing report container

    [Service]
    Restart=no
    ExecStartPre=/usr/bin/docker-credential-gcr configure-docker --registries=us-central1-docker.pkg.dev
    ExecStart=/usr/bin/docker run --pull=always --rm us-central1-docker.pkg.dev/myprojectname/reporting-repository/runreport /run.sh

- path: /etc/docker/daemon.json
  permissions: 0644
  owner: root
  content: |
    {
      "userns-remap": "default"
    }

runcmd:
- mount -t tmpfs -o mode=700 none /root
- install -m0644 /dev/null /etc/subuid
- install -m0644 /dev/null /etc/subgid
- systemctl restart docker
- systemctl daemon-reload
- systemctl start billingcontainer.service
```

Google's docs suggest setting the HOME environment variable on your service to redirect where docker-credential-gcr writes its config away from /root. If I had known that at the time, I would have done that, but I didn't, so I simply over-mounted the empty non-writable /root with a tmpfs. Again, you should probably follow their example, but this is just an example of something different.
