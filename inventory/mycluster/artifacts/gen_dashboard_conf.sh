#!/bin/bash

KUBECTL_CMD="${BASH_SOURCE%/*}/kubectl --kubeconfig=${BASH_SOURCE%/*}/admin.conf"
DASHBOARD_CFG=${BASH_SOURCE%/*}/dashboard.kubeconfig

$KUBECTL_CMD cluster-info || exit 1

NAMESPACE=kube-system
DASHBOARD_CFG=dashboard.kubeconfig
APISERVER=`$KUBECTL_CMD config view -o jsonpath='{.clusters[?(@.name=="cluster.local")].cluster.server}'`

# create ca.crt file
$KUBECTL_CMD config view --raw -o jsonpath='{.clusters[?(@.name=="cluster.local")].cluster.certificate-authority-data}' | base64 -d > ca.crt

# create dashboard-admin serviceaccount and clusterrolebinding into cluster  
$KUBECTL_CMD -n $NAMESPACE create sa dashboard-admin
$KUBECTL_CMD create clusterrolebinding dashboard-admin --clusterrole=cluster-admin --serviceaccount=$NAMESPACE:dashboard-admin

# get dashboard-admin secret token from cluster
TOKEN=`$KUBECTL_CMD -n $NAMESPACE get secret -o jsonpath="{.items[?(@.metadata.annotations.kubernetes\.io/service-account\.name == 'dashboard-admin')].data.token}" | base64 -d`

# 设置集群参数
./kubectl config set-cluster cluster.local \
--certificate-authority=ca.crt \
--embed-certs=true \
--server=$APISERVER \
--kubeconfig=$DASHBOARD_CFG

# 设置客户端认证参数，使用上面创建的 Token
./kubectl config set-credentials dashboard-admin \
--token=$TOKEN --kubeconfig=$DASHBOARD_CFG

# 设置上下文参数
./kubectl config set-context default \
--cluster=cluster.local --user=dashboard-admin --kubeconfig=$DASHBOARD_CFG

# 设置默认上下文
./kubectl config use-context default \
--kubeconfig=$DASHBOARD_CFG

# cleanup
rm -rf ca.crt