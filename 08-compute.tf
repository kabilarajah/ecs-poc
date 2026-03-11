# Dynamically fetch the latest ECS-Optimized Amazon Linux 2023 AMI
data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}

# The EC2 Launch Template
resource "aws_launch_template" "ecs_node" {
  name_prefix   = "${var.project_name}-ecs-node-"
  image_id      = data.aws_ssm_parameter.ecs_optimized_ami.value
  instance_type = "t3.small" # Good balance for a small project

  vpc_security_group_ids = [aws_security_group.ecs_nodes.id]

  iam_instance_profile {
    arn = aws_iam_instance_profile.ecs_node.arn
  }

  # Register the EC2 instance with our specific ECS Cluster
  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo "ECS_CLUSTER=${var.project_name}-cluster" >> /etc/ecs/ecs.config
  EOF
  )
}

# The Auto Scaling Group using 100% Spot Instances
resource "aws_autoscaling_group" "ecs_asg" {
  name                = "${var.project_name}-ecs-asg"
  vpc_zone_identifier = aws_subnet.private[*].id
  
  # For this project, 2 instances gives us high availability across our 2 AZs
  min_size            = 1
  max_size            = 3
  desired_capacity    = 2

  # Enable ECS managed termination protection so AWS doesn't kill an instance while a container is actively serving traffic
  protect_from_scale_in = true

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 0 # 100% Spot
      spot_allocation_strategy                 = "price-capacity-optimized"
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.ecs_node.id
        version            = "$Latest"
      }
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-ecs-spot-node"
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }
}