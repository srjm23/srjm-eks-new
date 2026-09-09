# EKS com Terraform

## AWS Load Balancer Controller

O arquivo `load-balancer-controller.tf` instala o controller em `kube-system`
via Helm, com duas réplicas e uma role IAM exclusiva via IRSA. Reutiliza o
OIDC do EKS e a policy em `policies/load-balancer-controller.json`.

O chart `3.5.0` instala o controller `v3.5.0`. Ao alterar
`load_balancer_controller_chart_version`, revise também a policy IAM conforme
a versão do controller.

Referências oficiais:
- https://docs.aws.amazon.com/eks/latest/userguide/lbc-helm.html
- https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/v3.5.0/helm/aws-load-balancer-controller/Chart.yaml
- https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/v3.5.0/docs/install/iam_policy.json

Com credenciais AWS configuradas e acesso ao endpoint do cluster, execute:

```sh
export TF_VAR_eks_public_access_cidr="SEU_IP_PUBLICO/32"
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

### Controller já instalado pelo terminal

Se o AWS Load Balancer Controller já foi instalado via Helm, importe a release
antes de gerar o plano, para o Terraform atualizar a instalação existente:

```sh
helm list -A
terraform import helm_release.load_balancer_controller kube-system/aws-load-balancer-controller
terraform plan -out=tfplan
terraform apply tfplan
```

O comando pressupõe release `aws-load-balancer-controller` em `kube-system`.
Se os nomes forem diferentes, ajuste `name`/`namespace` no recurso Helm e o
namespace no `sub` da trust policy antes da importação. Não importe novamente
se a release já estiver no state. Se apenas o Istio foi instalado manualmente
e o controller ainda não existe, use o fluxo de instalação sem importação.
Confira também a versão do chart em `helm list -A`: o padrão deste Terraform
é `3.5.0`; revise versão e policy antes de aplicar para evitar downgrade.

### Erro de credenciais no Service do Istio

`DescribeLoadBalancers ... no EC2 IMDS role found` indica que o controller não
conseguiu obter credenciais AWS. A role precisa estar associada ao ServiceAccount
do **AWS Load Balancer Controller**, mesmo que o erro apareça no Service
`istio/istio-ingress`.

O Terraform configura a trust policy OIDC com `sub` e `aud`, anota o
ServiceAccount com `eks.amazonaws.com/role-arn` e instala a policy IAM.
A annotation `checksum/irsa` no template do Deployment provoca um rollout
na adoção da release, permitindo que os novos pods recebam a configuração IRSA.
Região e VPC são explícitas para dispensar a descoberta via IMDS.

Após aplicar, verifique:

```sh
kubectl -n kube-system rollout status deployment/aws-load-balancer-controller
kubectl -n kube-system get sa aws-load-balancer-controller -o yaml
kubectl -n kube-system get deployment aws-load-balancer-controller -o yaml
kubectl -n kube-system logs deployment/aws-load-balancer-controller --since=5m
kubectl -n istio get svc istio-ingress -w
```

O ServiceAccount deve ter a annotation da role, e os novos pods devem receber
`AWS_ROLE_ARN` e `AWS_WEB_IDENTITY_TOKEN_FILE` (verifique com
`kubectl -n kube-system get pods -l app.kubernetes.io/name=aws-load-balancer-controller -o yaml`).
Eventos antigos podem continuar no `describe`; verifique se há novas ocorrências.

Revise o plano completo: os comandos operam sobre toda a infraestrutura deste
diretório. O IP de execução deve estar autorizado em `eks_public_access_cidr`.

Para verificar a instalação com o contexto Kubernetes apontando para o cluster:

```sh
kubectl -n kube-system rollout status deployment/aws-load-balancer-controller
kubectl -n kube-system get pods -l app.kubernetes.io/name=aws-load-balancer-controller
```

A instalação do controller não cria um balanceador por si só. Para um ALB
público, configure um Ingress da aplicação com `spec.ingressClassName: alb`
e a annotation `alb.ingress.kubernetes.io/scheme: internet-facing`.
As duas subnets públicas existentes já possuem a tag `kubernetes.io/role/elb`.
