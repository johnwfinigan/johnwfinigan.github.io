title: Quick XFS Quota Notes
date: 2023-10-13
css: style.css
tags: linux xfs multiuser quota

## Quick XFS Quota Notes

On multiuser systems, filesystem quotas are a low maintenance way to stop a single user from filling a partition. XFS quota support is good, and XFS project quotas provide a way to limit the growth of a directory tree even if it is not on a separate filesystem. These notes are really just a quick summary of ```man xfs_quota```. Tested on RHEL 7 and up.

### Per user quotas

```
xfs_quota -x -c 'limit bsoft=2g bhard=2g -d' /tmp          # set a default space quota, applies to each user but not root
 
xfs_quota -x -c 'limit bsoft=10g bhard=10g myuser' /tmp    # override the default for a particular user
 
xfs_quota -x -c 'report -h' /tmp                           # display report, find users who have hit quota
```

For user quotas to work, the filesystem must be mounted with the ```uquota``` option.

``` 
/dev/mapper/vg00-tmp   /tmp                   xfs     defaults,uquota        0 0
```


### Project Quotas

This lets you set a quota on a directory tree and tracks usage independent of what user owns the data.

In this example, the directory tree being limited is /home, and /home is part of the / filesystem. 10 is a project number that is arbitrary but needs to be unique per project quota.

```
xfs_quota -x -c 'project -s -p /home 10' /                # define a project number for /home
 
xfs_quota -x -c 'limit -p bhard=2g 10' /                  # set an overall limit on that project
```

For project quotas to work, the filesystem must be mounted with the ```pquota``` option. You can enable multiple quota types on the same filesystem.

``` 
/dev/mapper/vg00-home   /home                   xfs     defaults,pquota        0 0
```

### Special steps if enabling quotas on root

Tested only on RHEL 7.

If you are enabling project quotas on the root filesystem, add ```rootflags=pquota``` to ```/etc/default/grub``` (append to ```GRUB_CMDLINE_LINUX```)

For example, editing non-interactively:

```
sed -e 's/^GRUB_CMDLINE_LINUX="\(.\+\)"$/GRUB_CMDLINE_LINUX="\1 rootflags=pquota"/' /etc/default/grub
```

and then run ```grub2-mkconfig -o [...grub.cfg]``` to update kernel boot command options.

For example,

```
grub2-mkconfig -o  /boot/efi/EFI/centos/grub.cfg
```
