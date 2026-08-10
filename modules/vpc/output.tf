output "aws_subnets_public" {
  value = aws_subnet.public.*.id
}

output "aws_subnets_private" {
  value = aws_subnet.private.*.id
}

output "aws_subnets_secure" {
  value = aws_subnet.secure.*.id
}
output "vpc_id" {
  value = aws_vpc.my_vpc.id
}

output "secure_sg_id" {
  value = aws_security_group.secure_sg.id
}
output "appstream_sg_id" {
  value = aws_security_group.appstream_sg.id
}
output "efs_sg_id" {
  value = aws_security_group.efs_sg.id
}
output "vpce_sg_id" {
  value = aws_security_group.vpce_sg.id
}
output "kibana_alb_sg_id" {
  value = aws_security_group.kibana_alb_sg.id
}

output "alb_sg_id" {
  value = aws_security_group.alb_sg.id
}
output "cms_sg_id" {
  value = aws_security_group.cms_sg.id
}