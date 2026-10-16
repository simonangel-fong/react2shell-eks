# secret.tf

# Cloud crown jewel: a fake RDS credential in Secrets Manager.
resource "aws_secretsmanager_secret" "rds" {
  name                    = "${local.common_name}-rds-credential"
  description             = "RDS master credential (crown jewel)."
  recovery_window_in_days = 0 # allow immediate delete/recreate
}

resource "aws_secretsmanager_secret_version" "rds" {
  secret_id = aws_secretsmanager_secret.rds.id
  secret_string = jsonencode({
    username = "rds_admin"
    password = "RDS-sECrEt-InsECurE" # Intentional pwd
    engine   = "postgres"
    host     = "placeholder.rds.amazonaws.com"
    port     = 5432
    dbname   = "appdb"
  })
}
