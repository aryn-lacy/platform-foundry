output "state_bucket" {
  description = "S3 bucket backing all workspace states (locking via S3 conditional writes — no DynamoDB)."
  value       = aws_s3_bucket.state.bucket
}
