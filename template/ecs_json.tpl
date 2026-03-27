[
  {
    "name": "${container_name}",
    "image": "${image}",
    "essential": true,
    "portMappings": [
      {
        "containerPort": ${container_port},
        "hostPort": ${container_port},
        "protocol": "tcp"
      }
    ],
    "environment": ${environment_json},
    "secrets": ${secrets_json},
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${log_group_name}",
        "awslogs-region": "${aws_region}",
        "awslogs-stream-prefix": "ecs"
      }
    },
    "healthCheck": {
      "command": ["CMD-SHELL", "${healthcheck_cmd}"],
      "interval": ${health_interval},
      "timeout": ${health_timeout},
      "retries": ${health_retries},
      "startPeriod": ${health_start_time}
    }
  }
]
