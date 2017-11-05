/**
 * ECS Cluster creates a cluster with the following features:
 *
 *  - Autoscaling groups
 *  - Instance tags for filtering
 *  - EBS volume for docker resources
 *
 *
 * Usage:
 *
 *      module "microservices" {
 *        source               = "github.com/devops-workflow/terraform-aws-ecs-cluster"
 *        environment          = "prod"
 *        name                 = "microservices"
 *        vpc_id               = "vpc-id"
 *        image_id             = "ami-id"
 *        subnet_ids           = ["1" ,"2"]
 *        key_name             = "ssh-key"
 *        security_groups      = "1,2"
 *        iam_instance_profile = "id"
 *        region               = "us-west-2"
 *        availability_zones   = ["a", "b"]
 *        instance_type        = "t2.small"
 *      }
 *
 */

# TODO: Add environment prefix to all resources
#   Add tags (environment) to all resources that support tags

resource "aws_ecs_cluster" "main" {
  #name = "${var.namespaced ? var.environment : ""}${var.namespaced ? "-" : ""}${var.name}"
  name = "${var.namespaced ? format("%s-%s", var.environment, var.name) : var.name}"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "cluster" {
  name        = "${aws_ecs_cluster.main.name}-ecs-cluster"
  vpc_id      = "${var.vpc_id}"
  description = "Allows traffic from and to the EC2 instances of the ${aws_ecs_cluster.main.name} ECS cluster"
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = -1
    cidr_blocks     = ["${split(",", var.ingress_cidrs)}"]
    security_groups = ["${split(",", var.security_groups)}",
        "${aws_security_group.internal_elb.id}",
        "${aws_security_group.external_elb.id}",
      ]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = "${ merge(
    var.tags,
    map("Name", format("%s-ecs-cluster", aws_ecs_cluster.main.name) ),
    map("Environment", var.environment),
    map("Terraform", "true") )}"
  lifecycle {
    create_before_destroy = true
  }
}
/*
module "sg_lb" {
  source              = "../tf_security_groups"
  environment         = "${var.environment}"
  name                = "${var.name}"
  cidr                = "192.168.1.0/24"
  vpc_id              = "${var.vpc_id}"
  security_groups     = "${var.security_groups}"
} */

resource "aws_security_group" "internal_elb" {
  name = "${aws_ecs_cluster.main.name}-internal-elb"
  vpc_id      = "${var.vpc_id}"
  description = "Allows internal ELB traffic"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks     = ["${split(",", var.ingress_cidrs)}"]
    security_groups = ["${split(",", var.security_groups)}"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks     = ["${split(",", var.ingress_cidrs)}"]
    security_groups = ["${split(",", var.security_groups)}"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
  lifecycle {
    create_before_destroy = true
  }
  tags = "${ merge(
    var.tags,
    map("Name", var.namespaced ?
     format("%s-%s-internal-elb", var.environment, var.name) :
     format("%s-internal-elb", var.name) ),
    map("Environment", var.environment),
    map("Terraform", "true") )}"
}

resource "aws_security_group" "external_elb" {
  name = "${aws_ecs_cluster.main.name}-external-elb"
  vpc_id      = "${var.vpc_id}"
  description = "Allows external ELB traffic"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
  lifecycle {
    create_before_destroy = true
  }
  tags = "${ merge(
    var.tags,
    map("Name", var.namespaced ?
     format("%s-%s-external-elb", var.environment, var.name) :
     format("%s-external-elb", var.name) ),
    map("Environment", var.environment),
    map("Terraform", "true") )}"
}

data "template_file" "quay_auth" {
  template = "${file("${path.module}/files/quay_auth.sh")}"
  vars {
    quay_auth = "${var.quay_auth}"
    quay_user = "${var.quay_user}"
  }
}
data "template_file" "ecs_cloud_config" {
  template = "${file("${path.module}/files/cloud-config.yml.tpl")}"
  vars {
    environment       = "${var.environment}"
    name              = "${aws_ecs_cluster.main.name}"
    region            = "${var.region}"
    docker_auth_type  = "${var.docker_auth_type}" # dockercfg
    docker_auth_data  = "${var.docker_auth_data}"
    #docker_auth_data  = "${data.template_file.quay_auth.rendered}"
    quay_auth         = "${var.quay_auth}"
    quay_user         = "${var.quay_user}"
    # Use template?
    # {"https://quay.io": {"auth": "${quay_auth}", "email": ".", "username": "${quay_user}"}}
    #a = "${format("{"https://quay.io": {"auth": "%s", "email": ".", "username": "%s"}}", ,)}"
    ami               = "${var.image_id}"
    instance_type     = "${var.instance_type}"
  }
}

data "template_cloudinit_config" "cloud_config" {
  gzip          = false
  base64_encode = false
  part {
    content_type = "text/cloud-config"
    content      = "${data.template_file.ecs_cloud_config.rendered}"
  }
  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.quay_auth.rendered}"
  }
  #part {
  #  content_type = "${var.extra_cloud_config_type}"
  #  content      = "${var.extra_cloud_config_content}"
  #}
}

resource "aws_launch_configuration" "main" {
  name_prefix = "${format("%s-", aws_ecs_cluster.main.name)}"

  image_id                    = "${var.image_id}"
  instance_type               = "${var.instance_type}"
  ebs_optimized               = "${var.instance_ebs_optimized}"
  iam_instance_profile        = "${var.iam_instance_profile}"
  key_name                    = "${var.key_name}"
  security_groups             = ["${aws_security_group.cluster.id}"]
  user_data                   = "${data.template_cloudinit_config.cloud_config.rendered}"
  associate_public_ip_address = "${var.associate_public_ip_address}"
  # root
  root_block_device {
    volume_type = "gp2"
    volume_size = "${var.root_volume_size}"
  }
  # docker
  ebs_block_device {
    device_name = "/dev/xvdcz"
    volume_type = "gp2"
    volume_size = "${var.docker_volume_size}"
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "main" {
  name = "${aws_ecs_cluster.main.name}"

  availability_zones   = ["${var.availability_zones}"]
  vpc_zone_identifier  = ["${var.subnet_ids}"]
  launch_configuration = "${aws_launch_configuration.main.id}"
  min_size             = "${var.min_size}"
  max_size             = "${var.max_size}"
  desired_capacity     = "${var.desired_capacity}"
  termination_policies = ["OldestLaunchConfiguration", "Default"]

  tag {
    key                 = "Name"
    value               = "${aws_ecs_cluster.main.name}"
    propagate_at_launch = true
  }
  tag {
    key                 = "Cluster"
    value               = "${aws_ecs_cluster.main.name}"
    propagate_at_launch = true
  }
  tag {
    key                 = "Environment"
    value               = "${var.environment}"
    propagate_at_launch = true
  }
  tag {
    key                 = "Terraform"
    value               = "true"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${aws_ecs_cluster.main.name}-scaleup"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = "${aws_autoscaling_group.main.name}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${aws_ecs_cluster.main.name}-scaledown"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = "${aws_autoscaling_group.main.name}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${aws_ecs_cluster.main.name}-cpureservation-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUReservation"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Maximum"
  threshold           = "90"

  dimensions {
    ClusterName = "${aws_ecs_cluster.main.name}"
  }

  alarm_description = "Scale up if the cpu reservation is above 90% for 10 minutes"
  alarm_actions     = ["${aws_autoscaling_policy.scale_up.arn}"]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_metric_alarm" "memory_high" {
  alarm_name          = "${aws_ecs_cluster.main.name}-memoryreservation-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryReservation"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Maximum"
  threshold           = "90"

  dimensions {
    ClusterName = "${aws_ecs_cluster.main.name}"
  }

  alarm_description = "Scale up if the memory reservation is above 90% for 10 minutes"
  alarm_actions     = ["${aws_autoscaling_policy.scale_up.arn}"]

  lifecycle {
    create_before_destroy = true
  }

  # This is required to make cloudwatch alarms creation sequential, AWS doesn't
  # support modifying alarms concurrently.
  depends_on = ["aws_cloudwatch_metric_alarm.cpu_high"]
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${aws_ecs_cluster.main.name}-cpureservation-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUReservation"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Maximum"
  threshold           = "10"

  dimensions {
    ClusterName = "${aws_ecs_cluster.main.name}"
  }

  alarm_description = "Scale down if the cpu reservation is below 10% for 10 minutes"
  alarm_actions     = ["${aws_autoscaling_policy.scale_down.arn}"]

  lifecycle {
    create_before_destroy = true
  }

  # This is required to make cloudwatch alarms creation sequential, AWS doesn't
  # support modifying alarms concurrently.
  depends_on = ["aws_cloudwatch_metric_alarm.memory_high"]
}

resource "aws_cloudwatch_metric_alarm" "memory_low" {
  alarm_name          = "${aws_ecs_cluster.main.name}-memoryreservation-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryReservation"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Maximum"
  threshold           = "10"

  dimensions {
    ClusterName = "${aws_ecs_cluster.main.name}"
  }

  alarm_description = "Scale down if the memory reservation is below 10% for 10 minutes"
  alarm_actions     = ["${aws_autoscaling_policy.scale_down.arn}"]

  lifecycle {
    create_before_destroy = true
  }

  # This is required to make cloudwatch alarms creation sequential, AWS doesn't
  # support modifying alarms concurrently.
  depends_on = ["aws_cloudwatch_metric_alarm.cpu_low"]
}
