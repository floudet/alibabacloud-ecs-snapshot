# Automatic Snapshots for Alibaba Cloud (aliyun) ECS

Bash script for Automatic ECS Snapshots and Cleanup on Aliyun Elastic Compute Service. **Requires no user input!**

Inspiration (and the installation instructions) taken from: 
- AWS script [aws-ec2-ebs-automatic-snapshot-bash](https://github.com/CaseyLabs/aws-ec2-ebs-automatic-snapshot-bash)
- glcoud script [google-compute-snapshot](https://github.com/jacksegal/google-compute-snapshot)

## How it works
alicloud-snapshot.sh will:

- Determine the Instance ID of the Aliyun ECS server on which the script runs
- Get all the Disk IDs attached to that instance
- Current specifications for ECS limits the amount of snapshots for each disk to a maximum of 64. The script will delete associated snapshots for each Disk that meets or exceeds this quota.
- Take a snapshot of each Disk

The script has a number of **optional** usage options - for example you can:
- Reduce the amount of snapshots to keep [(-d)](#snapshot-retention)
- Create backup for another instance than the colling host [(-i)](#backing-up-remote-instance)
- Exclude Disks whose name contain a specific string [(-f)](#exclude-disks)

## Prerequisites
* `aliyun-cli` must be installed and configured

## Installation

ssh on to the server you wish to have backed up

**Install Script**: Download the latest version of the snapshot script and make it executable:
```
cd ~
wget https://raw.githubusercontent.com/floudet/alibabacloud-ecs-snapshot/master/alicloud-snapshot.sh
chmod +x alicloud-snapshot.sh
sudo mkdir -p /opt/alibabacloud-ecs-snapshot
sudo mv alicloud-snapshot.sh /opt/alibabacloud-ecs-snapshot/
```

**To manually test the script:**
```
sudo /opt/alibabacloud-ecs-snapshot/alicloud-snapshot.sh
```

**Setup CRON**: You should then setup a cron job in order to schedule a daily backup. Example cron for Debian based Linux:
```
0 5 * * * root /opt/alibabacloud-ecs-snapshot/alicloud-snapshot.sh >> /var/log/cron/snapshot.log 2>&1
```

Please note: the above command sends the output to a log file: `/var/log/cron/snapshot.log` - instructions for creating & managing the log file are below.

**Manage CRON Output**: You should then create a directory for all cron outputs and add it to logrotate:

- Create new directory:
``` 
sudo mkdir /var/log/cron 
```
- Create empty file for snapshot log:
```
sudo touch /var/log/cron/snapshot.log
```
- Change permissions on file:
```
sudo chgrp adm /var/log/cron/snapshot.log
sudo chmod 664 /var/log/cron/snapshot.log
```
- Create new entry in logrotate so cron files don't get too big :
```
sudo nano /etc/logrotate.d/cron
```
- Add the following text to the above file:
```
/var/log/cron/*.log {
    daily
    missingok
    rotate 14
    compress
    notifempty
    create 664 root adm
    sharedscripts
}
```

## Snapshot Retention
By default snapshots will be created until the ECS limit of 64 snapshot per disk is reached, however this quota can be reduced, by using the the -q flag:

    Usage: ./snapshot.sh [-q <quota>]
    
    Options:
    
       -q  Snapshot quota. ECS Snapshot 2.0 specifications: 64 snapshots max for each disk. If this quota is matched or exceeded, the oldest snapshots are deleted to allow the new one to be created.
           Default if not set: 64 [OPTIONAL]

## Backing up Remote Instance
By default the script will only backup disks attached to the calling Instance, however you can backup the disks for another instance, by using the -i flag:

    Usage: ./snapshot.sh [-i <instance_name>]
    
    Options:
    
       -i  Instance name to create backups for. If empty, makes backup for the calling host [OPTIONAL].

## Exclude Disks
By default, snapshots will be created for all attached disks. To exclude disks whose name contain a specific string, use the -f flag:

    Usage: ./snapshot.sh [-f <filter_string>]
    
    Options:
    
       -f  Exclude Disks whose name contain this specified string.


## License

MIT License

Copyright (c) 2018 Jack Segal
Copyright (c) 2019 Fabien Loudet

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
