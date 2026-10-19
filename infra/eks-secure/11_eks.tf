# eks.tf

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = local.eks_name
  kubernetes_version = local.eks_version

  endpoint_public_access  = true
  endpoint_private_access = true

  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets # nodes in private subnets

  # Core add-ons.
  addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
      configuration_values = jsonencode({
        enableNetworkPolicy = "true" # enable netpol
        nodeAgent = {
          enablePolicyEventLogs = "true" # enabel netpol logging; Costs ~1 extra vCPU per node for the aws-network-policy-agent.
          enableCloudWatchLogs  = "true"
        }
      })
    }
    eks-pod-identity-agent = {
      before_compute = true
    }
  }

  # Managed node group.
  eks_managed_node_groups = {
    default = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = [local.eks_node_type]

      min_size     = local.eks_node_min
      max_size     = local.eks_node_max
      desired_size = local.eks_node_desired

      # Secure posture: IMDSv2 required + hop limit 1.
      # Blocks pods (2 hops) from stealing the node role via IMDS,
      # forcing the intended IRSA path for the intentional breach.
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 1
      }
    }
  }
}
