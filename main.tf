locals {

  tags = {
    name        = var.cluster_name
    environment = var.environment
    team        = var.team
  }
  name = "${var.cluster_name}-${var.environment}"
}


module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "18.31.2"

  cluster_name              = local.name
  cluster_version           = var.cluster_version
  cluster_service_ipv4_cidr = "172.16.0.0/12"

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  vpc_id     = aws_vpc.eks_vpc.id
  subnet_ids = [aws_subnet.eks_private_subnet_1.id, aws_subnet.eks_private_subnet_2.id]

  enable_irsa = true

  #  eks_managed_node_group_defaults = {
  #    disk_size = 50
  #  }
  #
  #
  #  self_managed_node_group_defaults = {
  #    # enable discovery of autoscaling groups by cluster-autoscaler
  #    autoscaling_group_tags = {
  #      "k8s.io/cluster-autoscaler/enabled" : true,
  #      "k8s.io/cluster-autoscaler/${local.name}" : "owned",
  #    }
  #  }
  #  self_managed_node_groups = {
  #    one = {
  #      name          = "${local.name}-ng"
  #      instance_type = "t2.large"
  #      desired_size  = 1
  #      max_size      = 1
  #      min_size      = 1
  #
  #    }
  #  }
  tags = local.tags
}

module "eks_mng_linux_additional" {
  source  = "terraform-aws-modules/eks/aws//modules/_user_data"
  version = "18.31.2"

  pre_bootstrap_user_data = <<-EOT
    export USE_MAX_PODS=false
  EOT
}

locals {
  depends_on = [module.eks]
  kubeconfig = templatefile("templates/kubeconfig.tpl", {
    kubeconfig_name                   = local.name
    endpoint                          = module.eks.cluster_endpoint
    cluster_auth_base64               = module.eks.cluster_certificate_authority_data
    aws_authenticator_command         = "aws"
    aws_authenticator_command_args    = ["eks", "get-token", "--cluster-name", local.name]
    aws_authenticator_additional_args = []
    aws_authenticator_env_variables   = { AWS_PROFILE = "devops-techstack" }
  })
}

resource "local_file" "kubeconfig" {
  depends_on = [module.eks]
  content    = local.kubeconfig
  filename   = "kube.conf"
}

resource "null_resource" "delete_daemon_set" {
  depends_on = [module.eks, local_file.kubeconfig]

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "kubectl delete daemonset aws-node -n kube-system --kubeconfig=./kube.conf || true"
  }
}

resource "helm_release" "calico_cni" {
  depends_on = [null_resource.delete_daemon_set]
  name       = "calico"

  repository = "https://docs.tigera.io/calico/charts"
  chart      = "tigera-operator"
  version    = "v3.22.5"

  wait = false

}

resource "null_resource" "change_ip_pool" {
  depends_on = [module.eks_managed_node_group]
  triggers = {
    always_run = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = "sleep 10s; kubectl get ippool default-ipv4-ippool -o yaml --kubeconfig=./kube.conf | sed -e 's|cidr: 192.168.0.0/16|cidr: 172.16.0.0/12|' | kubectl apply --kubeconfig=./kube.conf -f - | kubectl describe ippool --kubeconfig=./kube.conf || true"
  }

}

resource "null_resource" "restart_calico_controller" {
  depends_on = [null_resource.change_ip_pool]
  triggers = {
    always_run = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = "kubectl rollout restart deploy calico-kube-controllers -n calico-system --kubeconfig=./kube.conf | kubectl get po -n calico-system --kubeconfig=./kube.conf || true"
  }

}

module "eks_managed_node_group" {
  source = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  version = "18.31.0"

  name            = "${local.name}-ng"
  cluster_name    = local.name
  cluster_version = var.cluster_version

  subnet_ids = [aws_subnet.eks_private_subnet_1.id, aws_subnet.eks_private_subnet_2.id]

  // The following variables are necessary if you decide to use the module outside of the parent EKS module context.
  // Without it, the security groups of the nodes are empty and thus won't join the cluster.
  cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
  vpc_security_group_ids            = [module.eks.node_security_group_id]

  disk_size = 50
  vpc_id = aws_vpc.eks_vpc.id
  min_size     = 1
  max_size     = 1
  desired_size = 1

  instance_types = ["t3.large"]
  capacity_type  = "ON_DEMAND"

  labels = local.tags

  pre_bootstrap_user_data = <<-EOT
    export USE_MAX_PODS=false
  EOT

  tags = local.tags
}