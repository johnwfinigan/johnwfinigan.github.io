title: Using IAP SSH to run Ansible in Google Cloud Build Triggers
date: 2023-05-08
css: simple.css
tags: gcp ansible iap

## Using IAP SSH to run Ansible in Google Cloud Build Triggers

Google pitches Cloud Build as the "serverless CI/CD platform" for Google Cloud (GCP). It's easy to use for infrastructure tasks like deploying cloud infrastructure using Terraform. This is great for ensuring that your Terraform build environment is repeatable and not tied to implicit state on a build machine. 

When a Cloud Build run is triggered, GCP runs a container of your choosing on a network that is, by default, not part of your customer-controlled VPC network. By default, traffic egressing from your Cloud Build will be seen by your instances as originating from a public IP of Google's choosing. This can be a problem if you want to use Cloud Build to run Ansible to configure your instances, since Ansible will typically log in to your instances using SSH. You could allow SSH traffic in from any public IP, but this is bad security practice if your only reason for doing this is admin access.

Another option is to do the config necessary to give Cloud Build access to your customer-controlled VPC network, by using Private Pools, which give a limited amount of control over the machine size and networking of the virtual hardware your builds run on. However, this requires some [configuration work](https://cloud.google.com/build/docs/private-pools/set-up-private-pool-to-use-in-vpc-network), including the use of Private Services Access to connect to your VPC network by VPC peering. Personally, I don't find this appealing. It injects a fair amount of accidental complexity for this simple use case.

But, there is another way. Google Cloud offers something called Identity Aware Proxy (IAP), which allows you to tunnel TCP traffic from anywhere to inside your VPC network, without your instances having public IPs. The ```gcloud compute ssh``` command has built in IAP support. I use this extensively for general admin access. It generally "just works".

All that remains is to plumb IAP SSH into Ansible, and do it in such a way that it can run in Cloud Build. 

The strategy here is to get Ansible to use ```gcloud compute ssh``` as its SSH provider, and to pass inventory between them in such a way that ```gcloud``` can recognize the instances, which essentially means using the instance name as defined in GCE.

Below is the Dockerfile for a runtime container that is compatible with Cloud Build:

```
FROM gcr.io/google.com/cloudsdktool/google-cloud-cli:slim

RUN $(gcloud info --format="value(basic.python_location)") -m pip install numpy
RUN python3 -m pip install ansible

ENV ANSIBLE_SSH_EXECUTABLE=/bin/g-ssh.sh
ENV ANSIBLE_CONFIG=/etc/g-ansible.cfg

COPY g-ssh.sh $ANSIBLE_SSH_EXECUTABLE
COPY g-ansible.cfg $ANSIBLE_CONFIG
```

This is a Debian-based Google Cloud SDK container. In my testing, an Alpine container had significantly worse performance for Ansible over IAP SSH. Numpy is installed to speed up IAP forwarding performance. In my testing, this improved performance significantly.

Inside this container is ```g-ssh.sh```, where the IAP SSH magic happens.

```
#!/bin/bash

umask 0077

# generate an ephemeral ssh key. exists only for this build step
if [ ! -f "$HOME/.ssh/google_compute_engine" ] ; then
  mkdir -p "$HOME/.ssh"
  ssh-keygen -t rsa -b 3072 -N "" -C "cloudbuild-$(date +%Y-%m-%d-%H-%M-%S)" -f $HOME/.ssh/google_compute_engine
fi

#
# adapted from https://unix.stackexchange.com/questions/545034/with-ansible-is-it-possible-to-connect-connect-to-hosts-that-are-behind-cloud-i
#

# get the two rightmost args to the script
host="${@: -2: 1}"
cmd="${@: -1: 1}"

# controlmasters is a performance optimization, added because gcloud ssh initiation is relatively slow
mkdir -p /workspace/.controlmasters/
# stagger parallel invocations of gcloud to prevent races - not clear how useful
flock /workspace/.lock1 sleep 1

# note that the --ssh-key-expire-after argument to gcloud is set, meaning that the ephemeral key
# will become invalid in OSLogin after one hour. Otherwise will end up with dozens of junk keys in OSLogin
gcloud_args=" --ssh-key-expire-after=1h --tunnel-through-iap --quiet --no-user-output-enabled -- -C -o ControlPath=/workspace/.controlmasters/%C -o ControlMaster=auto -o ControlPersist=300 -o PreferredAuthentications=publickey -o KbdInteractiveAuthentication=no -o PasswordAuthentication=no -o ConnectTimeout=20 "

# project and zone must be already set using gcloud config
exec gcloud compute ssh "$host" $gcloud_args "$cmd"
```

Note that an ephemeral SSH key is generated but has an expiration set. This key is lost when the build ends, and GCP will remove it from the authorized keys list when it expires after one hour. This is done using the ```--ssh-key-expire-after``` argument to gcloud. Thus there are no long lived SSH credentials involved here. I believe this SSH key management feature depends on the use of Google OSLogin on the instances. 

This leads the broader subject of roles and identity. The identity that is logging in to the instance and running Ansible commands will be the service account that your Cloud Build build runs as. This setup depends on that account being a valid OSLogin + IAP instance accessor account. That requires:

* There must be a [firewall rule on your VPC networks that allows IAP SSH](https://cloud.google.com/iap/docs/using-tcp-forwarding#create-firewall-rule) to reach instance private IPs from Google's designated IAP origination range. The instances do not require public IPs.

* The instances must have [OSLogin Enabled](https://cloud.google.com/compute/docs/oslogin/set-up-oslogin)

* The Cloud Build service account you use must have the following roles:
  * ```roles/compute.osAdminLogin``` on the instance or project
  * ```roles/iam.serviceAccountUser``` on the instance's service account
  * ```roles/iap.tunnelResourceAccessor``` on the project or tunnel

I have not tested with the default Cloud Build service account, but only with cloud build running as a custom service account. The Service Account User role may seem surprising, but OSLogin requires this for any account to be able to log in. I believe it is because any account that logs in to an instance can make requests using its service account, so this formalizes the relationship.  

Finally, in your container, you need a small Ansible config file, ```g-ansible.cfg```. I've been using this one for Ansible+IAP for years and don't remember all the details, but some tweaks were required to get file transfer (eg. Ansible ```copy:```) to work reliably. You may have to change the default ```interpreter_python``` based on the Linux version you run in your instances. I had to limit ```forks``` for stability, but have not extensively debugged to see what could be done to speed this up again.

```
[ssh_connection]
pipelining = True
ssh_args =
transfer_method = piped

[defaults]
forks = 1
interpreter_python = /usr/bin/python3
```

Here's a sample ```cloudbuild.yaml``` that uses this container to run Ansible through IAP in Cloud Build:

```
steps:

- id: 'test ansible'
  name: 'us-central1-docker.pkg.dev/my_project/cloudbuild-containers/cloudbuild-ansible-iap'
  entrypoint: '/bin/bash'
  args:
  - '-c'
  - |
    gcloud config set project my_example_project;
    gcloud config set compute/zone us-central1-a ;
    ansible-playbook -i ./test.ini test.yml
```

Note that you must set the project and zone in your build step. That is how ```g-ssh.sh``` knows how to find your instances by name.

This has worked well for me. Speed has been acceptable, but a more optimized build might create the IAP tunnels directly instead of using the ```gcloud compute ssh``` helper. This would allow using unwrapped openssh to access the instances, but would require some more complex state tracking that I have not yet spent time on.
