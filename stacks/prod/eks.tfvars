region              = "us-east-2"
environment         = "prod"
kubernetes_version  = "1.37" # standard support until 2027-11-30 (checked 2026-11-09)
node_instance_types = ["t3.medium"]
node_min_size       = 2 # 2 replicas spread across 2 AZs with PDB minAvailable 1
node_max_size       = 3
node_desired_size   = 2
admin_principal_arn = "arn:aws:iam::708884111549:user/modern-cloud-stack"
