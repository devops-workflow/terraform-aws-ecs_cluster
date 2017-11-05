
// The cluster name, e.g cdn
output "name" {
  value = "${var.name}"
}

// ECS Cluster Name
output "cluster_name" {
  value = "${aws_ecs_cluster.main.name}"
}
// ECS Cluster ID
output "cluster_id" {
  value = "${aws_ecs_cluster.main.id}"
}
// Cluster security group ID.
output "cluster_sg_id" {
  value = "${aws_security_group.cluster.id}"
}
// Internal LB security group ID.
output "internal_lb_sg_id" {
  value = "${aws_security_group.internal_elb.id}"
}
// External LB security group ID.
output "external_lb_sg_id" {
  value = "${aws_security_group.external_elb.id}"
}
// All Security Groups IDs
output "security_group_ids" {
  value = ["${aws_security_group.cluster.id}",
          "${aws_security_group.internal_elb.id}",
          "${aws_security_group.external_elb.id}"]
}
