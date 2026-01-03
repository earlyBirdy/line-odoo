resource "aws_efs_file_system" "this" {
  encrypted = true
  tags      = merge(var.tags, { Name = "${var.name}-efs" })
}

resource "aws_efs_mount_target" "mt" {
  count           = length(var.private_subnet_ids)
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = var.private_subnet_ids[count.index]
  security_groups = [var.sg_efs_id]
}
