# calico-eks
This Repository will allow you to create Calico as CNI for EKS Cluster, Also it will remove the max pod limit per node.


```aidl
terraform init
terraform plan -out calico-plan
terraform apply calico-plan --auto-approve

sh configmap.sh <CLUSTER-NAME>
```