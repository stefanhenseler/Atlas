output "Rancher Server URL" {
    value = "http://${aws_instance.rancher-server.public_dns}:8080"
}
output "Jenkins ELB URL" {
    value = "http://${aws_elb.rancher-elb-jenkins.dns_name}"
}
output "Nagios ELB URL" {
    value = "http://${aws_elb.rancher-elb-nagios.dns_name}/nagios"
}
