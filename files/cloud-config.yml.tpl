#cloud-config

package_update: true
#package_upgrade: true
#package_reboot_if_required: true

system_info:
  default_user:
    groups: [ "wheel", "docker" ]

bootcmd:
  - echo 'ami = ${ami}'
  - echo 'instance_type = ${instance_type}'

  #- echo 'SERVER_ENVIRONMENT=${environment}' >> /etc/environment
  #- echo 'SERVER_GROUP=${name}' >> /etc/environment
  #- echo 'SERVER_REGION=${region}' >> /etc/environment

  ### ECS Setup
  - mkdir -p /etc/ecs
  - echo 'ECS_CLUSTER=${name}' > /etc/ecs/ecs.config
  - echo 'ECS_ENGINE_AUTH_TYPE=${docker_auth_type}' >> /etc/ecs/ecs.config
  #- >
  #  echo 'ECS_ENGINE_AUTH_DATA=${docker_auth_data}' >> /etc/ecs/ecs.config
  # FIX: auth syntax here or in terraform (template/format)
  #- echo 'ECS_ENGINE_AUTH_DATA={"https://quay.io": {"auth": "${quay_auth}", "email": ".", "username": "${quay_user}"}}' >>/etc/ecs/ecs.config
  #- echo 'ECS_LOGLEVEL=debug' >> /etc/ecs/ecs.config
  # ECS_DATADIR=
  # ECS_LOGFILE=
  # ECS_UPDATE_DOWNLOAD_DIR=
  # ECS_IMAGE_CLEANUP_INTERVAL
  # ECS_IMAGE_MINIMUM_CLEANUP_AGE

  ### Docker Setup
  - echo DAEMON_MAXFILES=1048576 > /etc/sysconfig/docker
  - echo DAEMON_PIDFILE_TIMEOUT=10 >> /etc/sysconfig/docker
  - echo OPTIONS='"--default-ulimit nofile=1024:4096 --log-opt max-size=50m --log-opt max-file=5"' >> /etc/sysconfig/docker

  - [ cloud-init-per, instance, docker_storage_setup, /usr/bin/docker-storage-setup ]

packages:
  - perl-Switch
  - perl-DateTime
  - perl-Sys-Syslog
  - perl-LWP-Protocol-https
  - perl-Digest-SHA.x86_64
  - unzip

runcmd:
  # TODO: Improve to only dl if not exist. [ ! -d /usr/local/aws-scripts-mon ]
  - cd /usr/local/ && curl http://aws-cloudwatch.s3.amazonaws.com/downloads/CloudWatchMonitoringScripts-1.2.1.zip -O && unzip CloudWatchMonitoringScripts-1.2.1.zip && rm CloudWatchMonitoringScripts-1.2.1.zip
  # send disk, memory, swap utilization percentage CloudWatch stats for ASG
  - echo "* * * * * root /usr/local/aws-scripts-mon/mon-put-instance-data.pl --auto-scaling=only --swap-util --mem-util --disk-space-util --disk-path=/ --from-cron" >/etc/cron.d/aws-scripts-mon


# This stuff shouldn't be needed
#  sudo service docker stop
#  sudo service docker start
#
#  sudo stop ecs
#  sudo start ecs
