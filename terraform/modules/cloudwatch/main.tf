# CloudWatch module — log groups, metric alarms, SNS alerting, and dashboard.

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ── SNS Topic ─────────────────────────────────────────────────────────────────

resource "aws_sns_topic" "alerts" {
  name = "${local.name_prefix}-alerts"

  tags = {
    Name = "${local.name_prefix}-alerts"
  }
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ── Log Groups ────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "linux" {
  name              = "/nexusmidplane/${var.environment}/wildfly"
  retention_in_days = var.log_retention_days

  tags = {
    Name     = "${local.name_prefix}-wildfly-logs"
    instance = var.linux_instance_id
  }
}

resource "aws_cloudwatch_log_group" "windows" {
  name              = "/nexusmidplane/${var.environment}/iis"
  retention_in_days = var.log_retention_days

  tags = {
    Name     = "${local.name_prefix}-iis-logs"
    instance = var.windows_instance_id
  }
}

resource "aws_cloudwatch_log_group" "wildfly_app" {
  name              = "/nexusmidplane/${var.environment}/wildfly/application"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${local.name_prefix}-wildfly-app-logs"
  }
}

resource "aws_cloudwatch_log_group" "iis_app" {
  name              = "/nexusmidplane/${var.environment}/iis/application"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${local.name_prefix}-iis-app-logs"
  }
}

# ── CPU Alarms ────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "linux_cpu" {
  alarm_name          = "${local.name_prefix}-wildfly-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  alarm_description   = "WildFly CPU utilization above ${var.cpu_alarm_threshold}%"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = var.linux_instance_id
  }

  tags = {
    Name = "${local.name_prefix}-wildfly-cpu-alarm"
  }
}

resource "aws_cloudwatch_metric_alarm" "windows_cpu" {
  alarm_name          = "${local.name_prefix}-iis-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  alarm_description   = "IIS CPU utilization above ${var.cpu_alarm_threshold}%"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = var.windows_instance_id
  }

  tags = {
    Name = "${local.name_prefix}-iis-cpu-alarm"
  }
}

# ── Status Check Alarms ───────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "linux_status" {
  alarm_name          = "${local.name_prefix}-wildfly-status-check"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "WildFly instance status check failed"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = var.linux_instance_id
  }

  tags = {
    Name = "${local.name_prefix}-wildfly-status-alarm"
  }
}

resource "aws_cloudwatch_metric_alarm" "windows_status" {
  alarm_name          = "${local.name_prefix}-iis-status-check"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "IIS instance status check failed"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = var.windows_instance_id
  }

  tags = {
    Name = "${local.name_prefix}-iis-status-alarm"
  }
}

# ── Dashboard ─────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.name_prefix}-overview"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 1
        properties = {
          markdown = "# NexusMidplane — ${upper(var.environment)} Environment"
        }
      },
      # WildFly CPU
      {
        type   = "metric"
        x      = 0
        y      = 1
        width  = 8
        height = 6
        properties = {
          title  = "WildFly CPU Utilization"
          view   = "timeSeries"
          region = var.region
          period = 300
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", var.linux_instance_id]
          ]
          yAxis = { left = { min = 0, max = 100 } }
        }
      },
      # IIS CPU
      {
        type   = "metric"
        x      = 8
        y      = 1
        width  = 8
        height = 6
        properties = {
          title  = "IIS CPU Utilization"
          view   = "timeSeries"
          region = var.region
          period = 300
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", var.windows_instance_id]
          ]
          yAxis = { left = { min = 0, max = 100 } }
        }
      },
      # Network In/Out
      {
        type   = "metric"
        x      = 16
        y      = 1
        width  = 8
        height = 6
        properties = {
          title  = "Network I/O"
          view   = "timeSeries"
          region = var.region
          period = 300
          metrics = [
            ["AWS/EC2", "NetworkIn", "InstanceId", var.linux_instance_id, { label = "WildFly In" }],
            ["AWS/EC2", "NetworkOut", "InstanceId", var.linux_instance_id, { label = "WildFly Out" }],
            ["AWS/EC2", "NetworkIn", "InstanceId", var.windows_instance_id, { label = "IIS In" }],
            ["AWS/EC2", "NetworkOut", "InstanceId", var.windows_instance_id, { label = "IIS Out" }]
          ]
        }
      },
      # Disk Read/Write
      {
        type   = "metric"
        x      = 0
        y      = 7
        width  = 12
        height = 6
        properties = {
          title  = "Disk Operations"
          view   = "timeSeries"
          region = var.region
          period = 300
          metrics = [
            ["AWS/EC2", "DiskReadOps", "InstanceId", var.linux_instance_id, { label = "WildFly Read" }],
            ["AWS/EC2", "DiskWriteOps", "InstanceId", var.linux_instance_id, { label = "WildFly Write" }],
            ["AWS/EC2", "DiskReadOps", "InstanceId", var.windows_instance_id, { label = "IIS Read" }],
            ["AWS/EC2", "DiskWriteOps", "InstanceId", var.windows_instance_id, { label = "IIS Write" }]
          ]
        }
      },
      # Status checks
      {
        type   = "metric"
        x      = 12
        y      = 7
        width  = 12
        height = 6
        properties = {
          title  = "Status Checks"
          view   = "timeSeries"
          region = var.region
          period = 60
          metrics = [
            ["AWS/EC2", "StatusCheckFailed", "InstanceId", var.linux_instance_id, { label = "WildFly" }],
            ["AWS/EC2", "StatusCheckFailed", "InstanceId", var.windows_instance_id, { label = "IIS" }]
          ]
          yAxis = { left = { min = 0, max = 1 } }
        }
      }
    ]
  })
}
