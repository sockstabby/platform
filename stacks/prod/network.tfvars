region               = "us-east-2"
environment          = "prod"
vpc_cidr             = "10.20.0.0/16" # no overlap with debug (10.10.0.0/16)
public_subnet_cidrs  = ["10.20.0.0/24", "10.20.1.0/24"]
private_subnet_cidrs = ["10.20.16.0/20", "10.20.32.0/20"]
