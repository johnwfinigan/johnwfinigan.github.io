title: Using SSH over IAP TCP Forwarding to Build Compute Images with Packer in Google Cloud Build
date: 2023-06-30
css: style.css
tags: gcp ansible iap packer

## Using SSH over IAP TCP Forwarding to Build Compute Images with Packer in Google Cloud Build

[Previously I wrote](./Using-IAP-SSH-to-Run-Ansible-in-Google-Cloud-Build.html) about using Google Identity Aware Proxy based SSH to run Ansible within Google Cloud Build without needing a firewall penetration or network peering between Cloud Build and the target VMs, and without the target VMs needing public IPs. In this post I'll show how to use IAP TCP forwarding to build compute images using Hashicorp Packer running in Cloud Build, also without direct networking between Cloud Build and the ephemeral VM that Packer uses for the image build.

That previous post documents the necessary IAM and firewall rules needed for full IAP SSH to work, however here we are using IAP TCP forwarding, and SSH authentication is being handled by Packer itself instead of OSLogin, so only a subset of the requirements need to be met: the GCE firewall must allow IAP to communicate with the VM, and the Cloud Build service account must have IAM rights to start a tunnel to the VM (```roles/iap.tunnelResourceAccessor```)

Example cloudbuild.yaml - [Click here](./assets/cloudbuild-packer.yml) to view raw.

```
steps:
  - name: 'hashicorp/packer'
    entrypoint: sh
    args:
      - '-c'
      - |
          cp $(which packer) /workspace/
          chmod 555 /workspace/packer

  - name: 'gcr.io/google.com/cloudsdktool/google-cloud-cli:slim'
    env:
      - 'PACKER_NO_COLOR=true'
    entrypoint: bash
    args:
      - '-c'
      - |
          set -euo pipefail
          $(gcloud info --format="value(basic.python_location)") -m pip install numpy
          python3 -m pip install ansible
          touch ./log
          ( while ! grep -Fq "Instance has been created" ./log ; do 
              echo "waiting to start tunnel" ; 
              sleep 5 ; 
            done ; 
            sleep 60 ; 
            gcloud compute start-iap-tunnel packer-${BUILD_ID} 22 --local-host-port=127.0.0.1:22222 --zone=${_BUILD_ZONE} ) &
          /workspace/packer build \
            -var zone=${_BUILD_ZONE} \
            -var instance_name=packer-${BUILD_ID} \
            my_packerfile.pkr.hcl |& tee ./log

options:
  logging: CLOUD_LOGGING_ONLY
timeout: 3600s
```

Essentially, IAP TCP tunnelling is used to make port 22 on the target VM appear at port 22222 inside the Cloud Build runtime, and directives are added to the packerfile to link this all together, as shown below. In Cloud Build, ```$BUILD_ID``` is a built-in variable, but ```$_BUILD_ZONE``` is a user-supplied substitution that I am showing here since IAP tunneling and the compute instance have to be coordinated regarding the zone and the build VM's name. Your packerfile will contain something like this:

```
source "googlecompute" "my_build" {
  ...
  ...
  zone                    = "${var.zone}"
  disable_default_service_account = true
  instance_name           = "${var.instance_name}"
  ssh_host                = "127.0.0.1"
  ssh_port                = "22222"
  pause_before_connecting = "60s"
  metadata = { 
    enable-oslogin = "FALSE"
  }
  ...
  ...
}
```

Notably, this is not the prettiest shell scripting. There are probably race conditions in it, and some of the inserted waits may not actually be needed to avoid them. However, I've run a few dozen Linux image builds successfully using this code, and have not experienced a failure to connect yet.

Unlike my Ansible example, here I chose to rely on no custom containers and assemble everything needed using well known images.

As a bonus, here is some terraform you may be able to adapt to set up your firewall and IAM to allow IAP tunnelling to your VMs:

```
resource "google_compute_firewall" "allow-iap-ssh" {
  name    = "allow-iap-ssh"
  network = google_compute_network.FIXME.name
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["35.235.240.0/20"]
  priority      = "1000"
}

module "image-cloudbuild" {
  source       = "terraform-google-modules/service-accounts/google"
  names        = ["image-cloudbuild"]
  display_name = "image-cloudbuild"
  project_roles = [ 
    "FIXME_PROJECT=>roles/cloudbuild.builds.builder",
    "FIXME_PROJECT=>roles/compute.instanceAdmin.v1",
    "FIXME_PROJECT=>roles/compute.networkUser",
    "FIXME_PROJECT=>roles/iap.tunnelResourceAccessor",
  ]
}
```
