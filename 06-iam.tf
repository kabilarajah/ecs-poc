# IAM Role for EC2 instances to communicate with ECS
resource "aws_iam_role" "ecs_node_role" {
  name = "${var.project_name}-ecs-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach the managed ECS policy to the role
resource "aws_iam_role_policy_attachment" "ecs_node_role_policy" {
  role       = aws_iam_role.ecs_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# Instance Profile to attach the role to the EC2 instances
resource "aws_iam_instance_profile" "ecs_node" {
  name = "${var.project_name}-ecs-node-profile"
  role = aws_iam_role.ecs_node_role.name
}