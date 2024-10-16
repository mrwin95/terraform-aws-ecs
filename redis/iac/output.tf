output "efs_file_system_id" {
  description = "EFS File system ID"
  value       = aws_efs_file_system.redis_efs.id
}
